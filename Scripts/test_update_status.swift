import Foundation

@main
struct UpdateStatusTests {
    static func feed(_ items: String) -> Data {
        Data("<rss xmlns:sparkle=\"http://www.andymatuschak.org/xml-namespaces/sparkle\"><channel>\(items)</channel></rss>".utf8)
    }

    static func item(_ build: Int, version: String, minimumOS: String = "14.0", extra: String = "") -> String {
        """
        <item><sparkle:version>\(build)</sparkle:version>
        <sparkle:shortVersionString>\(version)</sparkle:shortVersionString>
        <sparkle:minimumSystemVersion>\(minimumOS)</sparkle:minimumSystemVersion>
        <enclosure url="https://github.com/akmumu/ttcalendar/releases/download/\(version)/ttcalendar.dmg"/>
        \(extra)</item>
        """
    }

    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let preferences = WidgetPreferences(directory: root)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let latest = AvailableAppUpdate(build: 29, version: "1.29")
        let data = feed(item(28, version: "1.28") + item(31, version: "1.31", minimumOS: "99.0")
            + item(30, version: "1.30", extra: "<sparkle:channel>beta</sparkle:channel>") + item(29, version: "1.29"))
        let parsed = try UpdateFeedParser.latest(in: data, systemVersion: "14.0")
        precondition(parsed == latest, "Only offer a supported stable release")
        let olderOS = try UpdateFeedParser.latest(in: data, systemVersion: "13.6")
        precondition(olderOS == nil)
        let attributeFeed = feed("<item><enclosure url=\"https://example.com/app.dmg\" sparkle:version=\"29\" sparkle:shortVersionString=\"1.29\"/></item>")
        let attributeItem = try UpdateFeedParser.latest(in: attributeFeed, systemVersion: "14.0")
        precondition(attributeItem == latest)

        for invalid in [Data("<rss>broken".utf8), Data("<html>not a feed</html>".utf8), Data(repeating: 0, count: 300_000)] {
            do {
                _ = try UpdateFeedParser.latest(in: invalid, systemVersion: "14.0")
                preconditionFailure("Invalid feed accepted")
            } catch {}
        }

        var requests = 0
        await WidgetUpdateChecker.refreshIfNeeded(now: now, preferences: preferences, systemVersion: "14.0") {
            requests += 1
            return data
        }
        precondition(requests == 1 && AppUpdateStore.availableUpdate(installedBuild: 28, preferences: preferences) == latest)
        precondition(AppUpdateStore.availableUpdate(installedBuild: 29, preferences: preferences) == nil, "Upgrade clears the badge")
        precondition(AppUpdateStore.availableUpdate(installedBuild: 30, preferences: preferences) == nil)
        await WidgetUpdateChecker.refreshIfNeeded(now: now.addingTimeInterval(60), preferences: preferences) {
            requests += 1
            return data
        }
        precondition(requests == 1, "Do not fetch on every timeline refresh")

        preferences.set("off", forKey: AppUpdateStore.automaticChecksKey)
        await WidgetUpdateChecker.refreshIfNeeded(now: now.addingTimeInterval(30_000), preferences: preferences) {
            requests += 1
            return data
        }
        precondition(requests == 1, "Respect disabled automatic checks")
        preferences.set("on", forKey: AppUpdateStore.automaticChecksKey)
        await WidgetUpdateChecker.refreshIfNeeded(now: now.addingTimeInterval(30_000), preferences: preferences) {
            throw URLError(.notConnectedToInternet)
        }
        precondition(AppUpdateStore.availableUpdate(installedBuild: 28, preferences: preferences) == latest, "Offline does not erase known updates")
        await WidgetUpdateChecker.refreshIfNeeded(now: now.addingTimeInterval(30_000), preferences: preferences) {
            Data("broken".utf8)
        }
        precondition(AppUpdateStore.availableUpdate(installedBuild: 28, preferences: preferences) == latest)

        preferences.set(29, forKey: AppUpdateStore.skippedBuildKey)
        precondition(AppUpdateStore.availableUpdate(installedBuild: 28, preferences: preferences) == nil)
        AppUpdateStore.save(AppUpdateStatus(checkedAt: now.addingTimeInterval(40_000), latest: AvailableAppUpdate(build: 30, version: "1.30")), preferences: preferences)
        AppUpdateStore.save(AppUpdateStatus(checkedAt: now, latest: nil), preferences: preferences)
        precondition(AppUpdateStore.availableUpdate(installedBuild: 28, preferences: preferences)?.build == 30, "A new release bypasses a prior skip; stale results cannot erase it")
        await WidgetUpdateChecker.refreshIfNeeded(now: now.addingTimeInterval(70_000), preferences: preferences) {
            feed(item(28, version: "1.28"))
        }
        precondition(AppUpdateStore.availableUpdate(installedBuild: 28, preferences: preferences) == nil)

        precondition(CalendarAppLink.action(for: CalendarAppLink.updates) == .updates)
        precondition(CalendarAppLink.action(for: CalendarAppLink.restartWidget) == .restartWidget)
        for url in ["https://updates", "ttcalendar://system-restart", "ttcalendar://restart-widget?all=true", "ttcalendar://updates/other", "ttcalendar://user@restart-widget"] {
            precondition(CalendarAppLink.action(for: URL(string: url)!) == nil)
        }
        print("PASS: supported releases, feed errors, throttling, opt-out, offline cache, version/skip handling, stale responses and safe links")
    }
}
