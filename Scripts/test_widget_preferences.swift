import Foundation

@main
struct WidgetPreferencesTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("widget")
        let host = WidgetPreferences(directory: directory)
        let widget = WidgetPreferences(directory: directory)
        precondition(widget.integer(forKey: "offset") == 0)
        precondition(widget.data(forKey: "holidays") == nil)
        let holidays = Data("{\"2026-09-25\":[{\"badgeText\":\"休\"}]}".utf8)
        precondition(host.set(holidays, forKey: "holidays"))
        precondition(widget.data(forKey: "holidays") == holidays)
        widget.set(2, forKey: "offset")
        host.set(123.5, forKey: "token")
        precondition(host.integer(forKey: "offset") == 2)
        precondition(widget.double(forKey: "token") == 123.5)
        precondition(widget.data(forKey: "holidays") == holidays)
        widget.set(0, forKey: "offset")
        precondition(host.integer(forKey: "offset") == 0)

        let legacy = root.appendingPathComponent("legacy")
        let preferences = legacy.appendingPathComponent("Library/Preferences")
        try FileManager.default.createDirectory(at: preferences, withIntermediateDirectories: true)
        let custom = Data("[]".utf8)
        let old = try PropertyListSerialization.data(fromPropertyList: ["customSpecialDates": custom], format: .binary, options: 0)
        try old.write(to: preferences.appendingPathComponent("group.akmumu.ttcalendar.plist"))
        try holidays.write(to: legacy.appendingPathComponent("cachedHolidayEvents.json"))
        host.migrateLegacyData(from: legacy)
        precondition(widget.data(forKey: "cachedHolidayEvents") == holidays)
        precondition(widget.data(forKey: "customSpecialDates") == custom)
        host.set(Data("[1]".utf8), forKey: "customSpecialDates")
        host.migrateLegacyData(from: legacy)
        precondition(widget.data(forKey: "customSpecialDates") == Data("[1]".utf8))

        let blocked = root.appendingPathComponent("not-a-directory")
        try Data().write(to: blocked)
        let failing = WidgetPreferences(directory: blocked)
        precondition(!failing.set(1, forKey: "offset"))
        precondition(failing.lastWriteError != nil)
        print("PASS: shared reads, isolated writes, migration, no overwrite, explicit write failures")
    }
}
