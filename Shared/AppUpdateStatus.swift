import Foundation

struct AvailableAppUpdate: Codable, Equatable {
    let build: Int
    let version: String
}

struct AppUpdateStatus: Codable, Equatable {
    let checkedAt: Date
    let latest: AvailableAppUpdate?
}

enum CalendarAppLink {
    static let updates = URL(string: "ttcalendar://updates")!
    static let restartWidget = URL(string: "ttcalendar://restart-widget")!

    enum Action { case updates, restartWidget }

    static func action(for url: URL) -> Action? {
        guard url.scheme == "ttcalendar", url.user == nil, url.password == nil,
              url.port == nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty || url.path == "/" else { return nil }
        switch url.host {
        case "updates": return .updates
        case "restart-widget": return .restartWidget
        default: return nil
        }
    }
}

enum AppUpdateStore {
    static let statusKey = "appUpdateStatus"
    static let automaticChecksKey = "automaticUpdateChecks"
    static let skippedBuildKey = "skippedUpdateBuild"
    static let checkInterval: TimeInterval = 6 * 60 * 60

    static var installedBuild: Int {
        Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0") ?? 0
    }

    static func load(preferences: WidgetPreferences = .shared) -> AppUpdateStatus? {
        guard let data = preferences.data(forKey: statusKey) else { return nil }
        return try? JSONDecoder().decode(AppUpdateStatus.self, from: data)
    }

    static func automaticChecksEnabled(preferences: WidgetPreferences = .shared) -> Bool {
        preferences.string(forKey: automaticChecksKey) != "off"
    }

    static func availableUpdate(installedBuild: Int = installedBuild,
                                preferences: WidgetPreferences = .shared) -> AvailableAppUpdate? {
        guard let latest = load(preferences: preferences)?.latest,
              latest.build > installedBuild,
              latest.build != preferences.integer(forKey: skippedBuildKey) else { return nil }
        return latest
    }

    static func needsCheck(now: Date = Date(), preferences: WidgetPreferences = .shared) -> Bool {
        guard automaticChecksEnabled(preferences: preferences) else { return false }
        guard let status = load(preferences: preferences) else { return true }
        let age = now.timeIntervalSince(status.checkedAt)
        return age < 0 || age >= checkInterval
    }

    @discardableResult
    static func save(_ status: AppUpdateStatus, preferences: WidgetPreferences = .shared) -> Bool {
        // An older, slower request must not erase a newer result from the app.
        if let current = load(preferences: preferences), current.checkedAt > status.checkedAt { return true }
        guard let data = try? JSONEncoder().encode(status) else { return false }
        return preferences.set(data, forKey: statusKey)
    }
}

// This reads only update availability from our public feed. Sparkle remains
// responsible for deciding what to install and verifying the download signature.
enum WidgetUpdateChecker {
    static let feedURL = URL(string: "https://akmumu.github.io/ttcalendar/appcast.xml")!

    static func refreshIfNeeded(
        now: Date = Date(),
        preferences: WidgetPreferences? = nil,
        systemVersion: String = ProcessInfo.processInfo.operatingSystemVersionStringForUpdates,
        fetch: () async throws -> Data = fetchFeed
    ) async {
        let preferences = preferences ?? WidgetPreferences.shared
        guard AppUpdateStore.needsCheck(now: now, preferences: preferences) else { return }
        do {
            let data = try await fetch()
            let latest = try UpdateFeedParser.latest(in: data, systemVersion: systemVersion)
            // Respect a setting changed while the request was in flight.
            guard AppUpdateStore.automaticChecksEnabled(preferences: preferences) else { return }
            AppUpdateStore.save(AppUpdateStatus(checkedAt: now, latest: latest), preferences: preferences)
        } catch {
            // Offline or malformed responses are not evidence that an update vanished.
        }
    }

    private static func fetchFeed() async throws -> Data {
        var request = URLRequest(url: feedURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        request.setValue("application/rss+xml, application/xml", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              response.url?.scheme == "https", response.url?.host == feedURL.host else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

private extension ProcessInfo {
    nonisolated var operatingSystemVersionStringForUpdates: String {
        let version = operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
}

final class UpdateFeedParser: NSObject, XMLParserDelegate {
    private var path: [String] = []
    private var text = ""
    private var fields: [String: String] = [:]
    private var hasDownload = false
    private var sawChannel = false
    private var items: [AvailableAppUpdate] = []
    private let systemVersion: String

    private init(systemVersion: String) { self.systemVersion = systemVersion }

    static func latest(in data: Data, systemVersion: String) throws -> AvailableAppUpdate? {
        guard data.count <= 256 * 1024 else { throw URLError(.dataLengthExceedsMaximum) }
        let delegate = UpdateFeedParser(systemVersion: systemVersion)
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse(), delegate.sawChannel else { throw URLError(.cannotParseResponse) }
        return delegate.items.max { $0.build < $1.build }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String]) {
        path.append(elementName)
        text = ""
        if path == ["rss", "channel"] { sawChannel = true }
        if path == ["rss", "channel", "item"] {
            fields = [:]
            hasDownload = false
        }
        if path == ["rss", "channel", "item", "enclosure"],
           attributes["sparkle:deltaFrom"] == nil,
           attributes["sparkle:os"] == nil || attributes["sparkle:os"] == "macos",
           let rawURL = attributes["url"], let url = URL(string: rawURL), url.scheme == "https" {
            hasDownload = true
            for key in ["sparkle:version", "sparkle:shortVersionString"] {
                if let value = attributes[key] { fields[key] = value }
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if path.count == 4, Array(path.prefix(3)) == ["rss", "channel", "item"] {
            fields[elementName] = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if path == ["rss", "channel", "item"], hasDownload,
           let rawBuild = fields["sparkle:version"], let build = Int(rawBuild), build > 0,
           let version = fields["sparkle:shortVersionString"],
           version.range(of: #"^\d+(\.\d+){1,3}$"#, options: .regularExpression) != nil,
           (fields["sparkle:channel"] ?? "").isEmpty,
           (fields["sparkle:minimumSystemVersion"] ?? "0").compare(systemVersion, options: .numeric) != .orderedDescending,
           fields["sparkle:maximumSystemVersion"].map({ $0.compare(systemVersion, options: .numeric) != .orderedAscending }) ?? true {
            items.append(AvailableAppUpdate(build: build, version: version))
        }
        path.removeLast()
        text = ""
    }
}
