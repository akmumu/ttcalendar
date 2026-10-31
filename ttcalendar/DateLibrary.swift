import Combine
import Foundation

enum DateLibraryError: LocalizedError {
    case unavailable, missing, exists, downloading, conflict, changed
    var errorDescription: String? {
        switch self {
        case .unavailable: return "无法访问当前日期库，请重新选择它的文件夹。"
        case .missing: return "这个文件夹里找不到日期库。请选择包含 customSpecialDates.plist 的文件夹。"
        case .exists: return "这里已有日期库。请用「打开已有库」打开，或另选文件夹保存。"
        case .downloading: return "正在从 iCloud 云盘下载日期库，请在下载完成后再试。"
        case .conflict: return "iCloud 报告日期库有冲突版本。请在访达保留各版本，确认要使用的库后重新打开。"
        case .changed: return "日期库已改变，请重新读取后再保存。"
        }
    }
}

// Coordinate with other local processes and the cloud file provider. Always compare
// the file read for an edit with the one being replaced inside the write accessor.
struct FolderDateFile: DateLibraryFile {
    static let filename = "customSpecialDates.plist"
    let folder: URL?
    private func location() throws -> URL {
        guard let folder else { throw DateLibraryError.unavailable }
        return folder.appendingPathComponent(Self.filename)
    }

    private func check(_ url: URL) throws {
        let placeholder = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).icloud")
        if FileManager.default.fileExists(atPath: placeholder.path) {
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
            throw DateLibraryError.downloading
        }
        if let state = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey, .ubiquitousItemHasUnresolvedConflictsKey]) {
            if state.ubiquitousItemHasUnresolvedConflicts == true { throw DateLibraryError.conflict }
            if state.ubiquitousItemDownloadingStatus == .notDownloaded {
                try FileManager.default.startDownloadingUbiquitousItem(at: url)
                throw DateLibraryError.downloading
            }
        }
        if !(NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []).isEmpty { throw DateLibraryError.conflict }
    }

    func read() throws -> Data {
        let url = try location()
        try check(url)
        var coordinationError: NSError?
        var result: Result<Data, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinationError) { file in
            result = Result { try Data(contentsOf: file) }
        }
        do {
            if let coordinationError { throw coordinationError }
            guard let result else { throw DateLibraryError.unavailable }
            return try result.get()
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile { throw DateLibraryError.missing }
    }

    func replace(_ data: Data, expecting original: Data?) throws {
        let url = try location()
        try check(url)
        var coordinationError: NSError?
        var result: Result<Void, Error>?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { file in
            result = Result {
                try check(file)
                if let original {
                    guard try Data(contentsOf: file) == original else { throw DateLibraryError.changed }
                    try data.write(to: file, options: .atomic)
                } else {
                    // Publish a complete new file without replacing an existing library.
                    let staging = file.deletingLastPathComponent().appendingPathComponent(".ttcalendar-\(UUID().uuidString)")
                    try data.write(to: staging, options: .withoutOverwriting)
                    defer { try? FileManager.default.removeItem(at: staging) }
                    do { try FileManager.default.moveItem(at: staging, to: file) }
                    catch let error as CocoaError where error.code == .fileWriteFileExists { throw DateLibraryError.exists }
                }
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw DateLibraryError.unavailable }
        try result.get()
    }
}

@MainActor
final class DateLibrary: ObservableObject {
    static let shared = DateLibrary()
    private let defaults: UserDefaults
    private let widget: WidgetPreferences
    private let key = "activeDateLibraryFolder"
    private var scopedURL: URL?
    private var lastFile: Data?
    private var monitor: Timer?
    @Published private(set) var path: String
    @Published private(set) var issue: String?
    @Published private(set) var cacheIssue: String?

    init(defaults: UserDefaults = .standard, widget: WidgetPreferences? = nil) {
        self.defaults = defaults
        self.widget = widget ?? .shared
        path = self.widget.directory.path
    }

    @Published var showSetup = false

    func offerSetupForNewInstall() {
        guard !defaults.bool(forKey: "dateLibrarySetupComplete"), defaults.object(forKey: key) == nil,
              widget.string(forKey: "lastOpenedBuild") == nil else { return }
        do { showSetup = try widget.readFile(forKey: "customSpecialDates") == nil } catch { }
    }

    func finishSetup() {
        defaults.set(true, forKey: "dateLibrarySetupComplete")
        showSetup = false
    }

    func resume() {
        guard let config = defaults.dictionary(forKey: key) else { return }
        path = config["path"] as? String ?? widget.directory.path
        // A missing volume or revoked bookmark must never silently select the old library.
        CustomSpecialDateStore.library = FolderDateFile(folder: nil)
        do {
            guard let data = config["bookmark"] as? Data else { throw DateLibraryError.unavailable }
            var stale = false
            let folder = try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI, .withoutMounting],
                                 relativeTo: nil, bookmarkDataIsStale: &stale)
            if folder.startAccessingSecurityScopedResource() { scopedURL = folder }
            CustomSpecialDateStore.library = FolderDateFile(folder: folder)
            path = folder.path
            if stale, let fresh = try? folder.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                defaults.set(["path": path, "bookmark": fresh], forKey: key)
            }
            monitorChanges()
        } catch { issue = error.localizedDescription }
    }

    func select(_ folder: URL, create: Bool) throws {
        let started = folder.startAccessingSecurityScopedResource()
        var retained = false
        defer { if started && !retained { folder.stopAccessingSecurityScopedResource() } }

        let target = FolderDateFile(folder: folder)
        let isDefault = folder.standardizedFileURL.resolvingSymlinksInPath().path == widget.directory.standardizedFileURL.resolvingSymlinksInPath().path
        if isDefault && create { throw DateLibraryError.exists }
        let bookmark = try folder.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        if create {
            let source = try CustomSpecialDateStore.currentFile(preferences: .shared)
            _ = try CustomSpecialDateStore.records(in: source)
            let blank = try PropertyListSerialization.data(fromPropertyList: ["value": Data("[]".utf8)], format: .binary, options: 0)
            try target.replace(source ?? blank, expecting: nil)
        }
        let file = try target.read()
        _ = try CustomSpecialDateStore.records(in: file)
        if isDefault {
            _ = try WidgetFolderAccess.authorize(folder)
            try widget.removeValue(forKey: CustomSpecialDateStore.widgetSnapshotKey)
            defaults.removeObject(forKey: key)
            CustomSpecialDateStore.library = nil
        } else {
            defaults.set(["path": folder.path, "bookmark": bookmark], forKey: key)
            CustomSpecialDateStore.library = target
        }
        scopedURL?.stopAccessingSecurityScopedResource()
        scopedURL = started ? folder : nil
        retained = started
        path = folder.path
        issue = nil
        cacheIssue = nil
        lastFile = nil
        monitor?.invalidate()
        if !isDefault {
            _ = refresh()
            monitorChanges()
        }
        notify()
    }

    private func monitorChanges() {
        monitor?.invalidate()
        monitor = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkForChanges() }
        }
    }

    private func notify() {
        NotificationCenter.default.post(name: CustomSpecialDateStore.didChangeNotification, object: nil)
        DateReminderService.shared.refresh()
        AppInstallRefreshCoordinator.reloadWidgetsRepeatedly()
    }

    @objc func datesChanged(_ notification: Notification) { _ = refresh() }
    func checkForChanges() { if refresh() { notify() } }

    @discardableResult
    func refresh() -> Bool {
        guard let library = CustomSpecialDateStore.library else { return false }
        do {
            let current = try library.read()
            let changed = current != lastFile || issue != nil
            guard changed || cacheIssue != nil else { return false }
            _ = try CustomSpecialDateStore.records(in: current)
            let data = try WidgetPreferences.payload(from: current)
            if widget.set(data, forKey: CustomSpecialDateStore.widgetSnapshotKey) {
                cacheIssue = nil
            } else {
                cacheIssue = "小组件暂时无法显示当前库。请授权小组件数据文件夹。"
            }
            lastFile = current
            issue = nil
            return changed
        } catch {
            let changed = issue != error.localizedDescription
            issue = error.localizedDescription
            return changed
        }
    }
}
