import Foundation

// Only the host needs a user grant. The extension already owns this directory.
@MainActor
enum WidgetFolderAccess {
    private static let bookmarkKey = "widgetFolderAccessBookmark"
    private static var scopedURL: URL?

    private enum AccessError: LocalizedError {
        case wrongFolder, missingDates

        var errorDescription: String? {
            switch self {
            case .wrongFolder: return "请选择小组件原来的 ttcalendar 文件夹。可复制错误提示下方的路径。"
            case .missingDates: return "在所选目录里找不到 customSpecialDates.plist。请核对原日期文件的位置。"
            }
        }
    }

    static func isPermissionError(_ error: Error) -> Bool {
        let error = error as NSError
        if error.domain == NSCocoaErrorDomain, error.code == NSFileReadNoPermissionError { return true }
        if error.domain == NSPOSIXErrorDomain, [Int(EACCES), Int(EPERM)].contains(error.code) { return true }
        return (error.userInfo[NSUnderlyingErrorKey] as? NSError).map(isPermissionError) ?? false
    }

    private static func matchesDirectory(_ url: URL, _ directory: URL) -> Bool {
        url.isFileURL && url.standardizedFileURL.resolvingSymlinksInPath().path ==
            directory.standardizedFileURL.resolvingSymlinksInPath().path
    }

    static func restore(directory: URL? = nil, defaults: UserDefaults = .standard) {
        guard let data = defaults.data(forKey: bookmarkKey) else { return }
        do {
            var stale = false
            let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI, .withoutMounting],
                              relativeTo: nil, bookmarkDataIsStale: &stale)
            guard matchesDirectory(url, directory ?? WidgetPreferences.storageDirectory), url.startAccessingSecurityScopedResource() else { return }
            scopedURL?.stopAccessingSecurityScopedResource()
            scopedURL = url
            if stale { try saveBookmark(for: url, defaults: defaults) }
        } catch {
            // A revoked grant can be selected again from the date management view.
        }
    }

    static func authorize(_ url: URL, preferences: WidgetPreferences? = nil,
                          defaults: UserDefaults = .standard) throws -> String? {
        let preferences = preferences ?? .shared
        guard matchesDirectory(url, preferences.directory) else { throw AccessError.wrongFolder }
        let started = url.startAccessingSecurityScopedResource()
        do {
            // Prove the existing record file can actually be read before accepting the grant.
            guard let data = try preferences.readData(forKey: "customSpecialDates") else { throw AccessError.missingDates }
            _ = try JSONDecoder().decode([CustomSpecialDate].self, from: data)
        } catch {
            if started { url.stopAccessingSecurityScopedResource() }
            throw error
        }
        if started {
            scopedURL?.stopAccessingSecurityScopedResource()
            scopedURL = url
        }
        do {
            try saveBookmark(for: url, defaults: defaults)
            return nil
        } catch {
            return "已读到原日期。本次授权未能保存，下次打开时可能需要再次选择文件夹。"
        }
    }

    private static func saveBookmark(for url: URL, defaults: UserDefaults) throws {
        let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(data, forKey: bookmarkKey)
    }
}
