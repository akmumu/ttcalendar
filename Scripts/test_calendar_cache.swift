import Foundation

@main
struct CalendarCacheTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let preferences = WidgetPreferences(directory: root)
        let event = CachedCalendarEvent(dateKey: "2026-10-01", title: "国庆节", badgeText: "休")
        CalendarEventCache.save([event, event], preferences: preferences)
        precondition(preferences.lastWriteError == nil)
        let data = preferences.data(forKey: "cachedHolidayEvents")!
        let saved = try JSONDecoder().decode([String: [CachedCalendarEvent]].self, from: data)
        precondition(saved[event.dateKey] == [event])
        precondition(preferences.double(forKey: "widgetRefreshToken") > 0)

        // Fail only the calendar write while the auxiliary token remains writable.
        // A subsequent successful token write used to erase this failure.
        let cacheFile = root.appendingPathComponent("cachedHolidayEvents.plist")
        try FileManager.default.removeItem(at: cacheFile)
        try FileManager.default.createDirectory(at: cacheFile, withIntermediateDirectories: true)
        preferences.set(123.0, forKey: "widgetRefreshToken")
        CalendarEventCache.save([event], preferences: preferences)
        precondition(preferences.lastWriteError != nil, "A failed sync must remain visible")
        precondition(preferences.double(forKey: "widgetRefreshToken") == 123.0, "Don't report a new cache after failure")

        try FileManager.default.removeItem(at: cacheFile)
        CalendarEventCache.save([event], preferences: preferences)
        precondition(preferences.lastWriteError == nil)
        precondition(preferences.data(forKey: "cachedHolidayEvents") != nil)
        precondition(preferences.double(forKey: "widgetRefreshToken") > 123.0)
        print("PASS: cache deduplication, failed-write reporting, unchanged token on failure, recovery")
    }
}
