import Combine
import CryptoKit
import Foundation

/// Backups use the same plist wrapper as the original file, including IDs and reminders.
enum DateBackupFile {
    static func checkedDates(_ data: Data) throws -> [CustomSpecialDate] {
        let dates = try JSONDecoder().decode([CustomSpecialDate].self, from: data)
        guard Set(dates.map(\.id)).count == dates.count,
              dates.allSatisfy({ (1...12).contains($0.month) && (1...31).contains($0.day) }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return dates
    }

    nonisolated static func write(_ data: Data, in folder: URL) throws -> URL {
        let plist = try PropertyListSerialization.data(fromPropertyList: ["value": data], format: .binary, options: 0)
        return try writeFile(plist, in: folder)
    }

    nonisolated static func writeFile(_ plist: Data, in folder: URL) throws -> URL {
        let timestamp = Date().ISO8601Format().replacingOccurrences(of: ":", with: "-")
        let device = (Host.current().localizedName ?? "Mac").components(separatedBy: CharacterSet(charactersIn: "/:")).joined(separator: "-")
        let name = "抬头日历-\(device.prefix(48))-\(timestamp)-\(UUID().uuidString).plist"
        let file = folder.appendingPathComponent(name)
        try plist.write(to: file, options: .atomic)
        return file
    }

    nonisolated static func read(_ file: URL) throws -> Data {
        let scoped = file.startAccessingSecurityScopedResource()
        defer { if scoped { file.stopAccessingSecurityScopedResource() } }
        let state = try file.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
        if state.ubiquitousItemDownloadingStatus == .notDownloaded {
            try FileManager.default.startDownloadingUbiquitousItem(at: file)
            throw BackupError.downloading
        }
        var error: NSError?
        var result: Result<Data, Error>?
        NSFileCoordinator().coordinate(readingItemAt: file, options: .withoutChanges, error: &error) { local in
            result = Result {
                try WidgetPreferences.payload(from: Data(contentsOf: local))
            }
        }
        if let error { throw error }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return try result.get()
    }

    enum BackupError: LocalizedError {
        case downloading, localChanged
        var errorDescription: String? {
            switch self {
            case .downloading: return "已请求从 iCloud 云盘下载此备份。请等下载完成后再选择该文件。"
            case .localChanged: return "日期库在预览后发生了变化。请重新选择备份再确认恢复。"
            }
        }
    }
}

@MainActor
final class DateBackupService: ObservableObject {
    static let shared = DateBackupService()
    private let defaults: UserDefaults
    private let preferences: WidgetPreferences
    private let rollbackFolder: URL
    private let configKey = "dateBackupFolder"
    private let digestKey = "lastDateBackupDigest"
    private let dateKey = "lastDateBackupTime"
    private var pending: Task<Void, Never>?
    @Published private(set) var folderPath: String?
    @Published private(set) var lastBackup: Date?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isWriting = false

    init(defaults: UserDefaults = .standard, preferences: WidgetPreferences? = nil, rollbackFolder: URL? = nil) {
        self.defaults = defaults
        self.preferences = preferences ?? .shared
        self.rollbackFolder = rollbackFolder ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ttcalendar/恢复前备份", isDirectory: true)
        folderPath = defaults.dictionary(forKey: configKey)?["path"] as? String
        lastBackup = defaults.object(forKey: dateKey) as? Date
    }

    func chooseFolder(_ folder: URL) throws {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        let bookmark = try folder.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(["path": folder.path, "bookmark": bookmark], forKey: configKey)
        defaults.removeObject(forKey: digestKey)
        defaults.removeObject(forKey: dateKey)
        lastBackup = nil
        folderPath = folder.path
        enqueue()
    }

    func disable() {
        defaults.removeObject(forKey: configKey)
        defaults.removeObject(forKey: digestKey)
        defaults.removeObject(forKey: dateKey)
        folderPath = nil
        lastBackup = nil
        errorMessage = nil
    }

    @objc func datesChanged(_ notification: Notification) { enqueue() }

    func enqueue(force: Bool = false) {
        guard let bookmark = defaults.dictionary(forKey: configKey)?["bookmark"] as? Data else { return }
        let payload: Data
        do {
            guard let file = try CustomSpecialDateStore.currentFile(preferences: preferences) else {
                errorMessage = "添加第一条日期后会自动备份。"
                return
            }
            payload = try WidgetPreferences.payload(from: file)
            _ = try DateBackupFile.checkedDates(payload)
        } catch {
            errorMessage = "无法备份当前日期库：\(error.localizedDescription)"
            return
        }
        let digest = Data(SHA256.hash(data: payload))
        let previous = pending
        isWriting = true
        let id = UUID()
        latestRequest = id
        pending = Task {
            await previous?.value
            defer { if latestRequest == id { isWriting = false; pending = nil } }
            guard defaults.dictionary(forKey: configKey)?["bookmark"] as? Data == bookmark else { return }
            if !force && defaults.data(forKey: digestKey) == digest { errorMessage = nil; return }
            do {
                let folder = try await Task.detached(priority: .utility) {
                    var stale = false
                    let url = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI, .withoutMounting],
                                      relativeTo: nil, bookmarkDataIsStale: &stale)
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    _ = try DateBackupFile.write(payload, in: url)
                    let refreshed = stale ? try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) : bookmark
                    return (url.path, refreshed)
                }.value
                guard defaults.dictionary(forKey: configKey)?["bookmark"] as? Data == bookmark else { return }
                // Keep queued writes valid if a bookmark was renewed during a burst of edits.
                if latestRequest == id {
                    defaults.set(["path": folder.0, "bookmark": folder.1], forKey: configKey)
                    folderPath = folder.0
                }
                defaults.set(digest, forKey: digestKey)
                let now = Date()
                defaults.set(now, forKey: dateKey)
                lastBackup = now
                errorMessage = nil
            } catch { errorMessage = "写入备份失败：\(error.localizedDescription)" }
        }
    }

    private var latestRequest: UUID?
    func finishPendingWrites() async { await pending?.value }

    struct Preview {
        let name: String
        let dates: [CustomSpecialDate]
        fileprivate let previousFile: Data?
        let previousCount: Int?
    }

    func preview(_ file: URL) async throws -> Preview {
        let payload = try await Task.detached { try DateBackupFile.read(file) }.value
        let dates = try DateBackupFile.checkedDates(payload)
        let previous = try CustomSpecialDateStore.currentFile(preferences: preferences)
        let count = previous.map { raw in try? DateBackupFile.checkedDates(WidgetPreferences.payload(from: raw)).count } ?? 0
        return Preview(name: file.lastPathComponent, dates: dates, previousFile: previous, previousCount: count)
    }

    /// Read the local list again immediately before replacement, after user confirmation.
    func restore(_ preview: Preview) throws -> URL? {
        let current = try CustomSpecialDateStore.currentFile(preferences: preferences)
        guard current == preview.previousFile else { throw DateBackupFile.BackupError.localChanged }
        var safetyCopy: URL?
        if let current {
            try FileManager.default.createDirectory(at: rollbackFolder, withIntermediateDirectories: true)
            safetyCopy = try DateBackupFile.writeFile(current, in: rollbackFolder)
        }
        try CustomSpecialDateStore.replaceFromBackup(preview.dates, expectedFile: current, preferences: preferences)
        return safetyCopy
    }
}
