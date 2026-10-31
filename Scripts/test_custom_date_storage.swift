import Foundation

@main
struct CustomDateStorageTests {
    static func expectFailure(_ operation: () throws -> Void) {
        do {
            try operation()
            preconditionFailure("Expected a storage error")
        } catch {}
    }

    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("widget")
        let preferences = WidgetPreferences(directory: directory)
        let file = directory.appendingPathComponent("customSpecialDates.plist")
        let original = CustomSpecialDate(month: 10, day: 31, type: .birthday, name: "生日")
        let another = CustomSpecialDate(month: 11, day: 1, type: .meeting, name: "会议")

        let empty = try CustomSpecialDateStore.loadChecked(preferences: preferences)
        precondition(empty.isEmpty, "A new installation has no dates")
        try CustomSpecialDateStore.add(original, preferences: preferences)
        let saved = try Data(contentsOf: file)
        let encodedDates = try preferences.readData(forKey: "customSpecialDates")
        precondition(encodedDates != nil)

        // A denied read must not become an empty list or permit a destructive write.
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: file.path)
        expectFailure { _ = try CustomSpecialDateStore.loadChecked(preferences: preferences) }
        expectFailure { try CustomSpecialDateStore.add(another, preferences: preferences) }
        expectFailure { try CustomSpecialDateStore.update(original, preferences: preferences) }
        expectFailure { try CustomSpecialDateStore.delete(original, preferences: preferences) }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        let afterDeniedRead = try Data(contentsOf: file)
        precondition(afterDeniedRead == saved, "Read failures must preserve the original file")

        let suite = "ttcalendar-folder-tests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let wrongFolder = root.appendingPathComponent("other/widget")
        try FileManager.default.createDirectory(at: wrongFolder, withIntermediateDirectories: true)
        expectFailure { _ = try WidgetFolderAccess.authorize(wrongFolder, preferences: preferences, defaults: defaults) }
        expectFailure { _ = try WidgetFolderAccess.authorize(wrongFolder, preferences: WidgetPreferences(directory: wrongFolder), defaults: defaults) }
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: file.path)
        do {
            _ = try WidgetFolderAccess.authorize(directory, preferences: preferences, defaults: defaults)
            preconditionFailure("Do not accept an unreadable folder")
        } catch {
            precondition(WidgetFolderAccess.isPermissionError(error))
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        _ = try WidgetFolderAccess.authorize(directory, preferences: preferences, defaults: defaults)
        WidgetFolderAccess.restore(directory: directory, defaults: defaults)
        let dataAfterGrant = try Data(contentsOf: file)
        precondition(dataAfterGrant == saved)
        precondition(!WidgetFolderAccess.isPermissionError(CocoaError(.propertyListReadCorrupt)))

        // Both invalid wrappers and undecodable date records must be reported.
        for damaged in [Data("broken plist".utf8),
                        try PropertyListSerialization.data(fromPropertyList: ["value": "wrong type"], format: .binary, options: 0),
                        try PropertyListSerialization.data(fromPropertyList: ["value": Data("broken json".utf8)], format: .binary, options: 0)] {
            try damaged.write(to: file)
            expectFailure { _ = try CustomSpecialDateStore.loadChecked(preferences: preferences) }
            expectFailure { try CustomSpecialDateStore.add(another, preferences: preferences) }
            expectFailure { try CustomSpecialDateStore.update(original, preferences: preferences) }
            expectFailure { try CustomSpecialDateStore.delete(original, preferences: preferences) }
            let unchanged = try Data(contentsOf: file)
            precondition(unchanged == damaged)
        }

        try saved.write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
        expectFailure { try CustomSpecialDateStore.add(another, preferences: preferences) }
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let afterFailedWrite = try CustomSpecialDateStore.loadChecked(preferences: preferences)
        precondition(afterFailedWrite == [original], "Failed writes must keep saved records")

        try CustomSpecialDateStore.add(another, preferences: preferences)
        var edited = original
        edited.name = "新名字"
        try CustomSpecialDateStore.update(edited, preferences: preferences)
        try CustomSpecialDateStore.delete(another, preferences: preferences)
        let recovered = try CustomSpecialDateStore.loadChecked(preferences: preferences)
        precondition(recovered == [edited])
        expectFailure { try CustomSpecialDateStore.update(another, preferences: preferences) }
        try CustomSpecialDateStore.delete(edited, preferences: preferences)
        let deleted = try CustomSpecialDateStore.loadChecked(preferences: preferences)
        precondition(deleted.isEmpty, "Deleting the final record still produces a valid empty list")
        print("PASS: missing data, denied reads, corrupt data, failed writes, recovery and mutations")
    }
}
