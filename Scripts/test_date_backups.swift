import Foundation

@main
struct DateBackupTests {
    @MainActor static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaults = UserDefaults(suiteName: root.lastPathComponent)!
        defer {
            defaults.removePersistentDomain(forName: root.lastPathComponent)
            try? FileManager.default.removeItem(at: root)
        }
        let source = WidgetPreferences(directory: root.appendingPathComponent("widget"))
        let folder = root.appendingPathComponent("copies")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let rollback = root.appendingPathComponent("before")
        let service = DateBackupService(defaults: defaults, preferences: source, rollbackFolder: rollback)
        func files() throws -> [URL] { try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) }
        func records(_ file: URL) throws -> [CustomSpecialDate] { try DateBackupFile.checkedDates(DateBackupFile.read(file)) }

        let initial = CustomSpecialDate(month: 2, day: 29, type: .birthday, name: "生日", reminder: DateReminder())
        try CustomSpecialDateStore.add(initial, preferences: source)
        try service.chooseFolder(folder)
        await service.finishPendingWrites()
        let first = try files()
        precondition(first.count == 1 && service.errorMessage == nil)
        let saved = try Data(contentsOf: first[0])
        let restoredService = DateBackupService(defaults: defaults, preferences: source, rollbackFolder: rollback)
        restoredService.enqueue()
        await restoredService.finishPendingWrites()
        let unchanged = try files()
        precondition(unchanged.count == 1, "Relaunch must not duplicate an unchanged backup")

        let later = CustomSpecialDate(month: 9, day: 8, type: .meeting, name: "开会")
        try CustomSpecialDateStore.add(later, preferences: source)
        restoredService.enqueue()
        try CustomSpecialDateStore.delete(initial, preferences: source)
        restoredService.enqueue()
        await restoredService.finishPendingWrites()
        let histories = try files().map(records)
        precondition(histories.count == 3 && histories.contains([initial, later]) && histories.contains([later]))
        let firstAgain = try Data(contentsOf: first[0])
        precondition(saved == firstAgain)
        let preview = try await restoredService.preview(first[0])
        let stillLocal = try CustomSpecialDateStore.loadChecked(preferences: source)
        precondition(stillLocal == [later] && preview.dates == [initial])
        try CustomSpecialDateStore.add(initial, preferences: source)
        do {
            _ = try restoredService.restore(preview)
            preconditionFailure("An outdated preview must not overwrite newer edits")
        } catch DateBackupFile.BackupError.localChanged {}
        let refreshed = try await restoredService.preview(first[0])
        let original = try restoredService.restore(refreshed)!
        let before = try records(original)
        let after = try CustomSpecialDateStore.loadChecked(preferences: source)
        precondition(before == [later, initial] && after == [initial])

        restoredService.disable()
        restoredService.enqueue()
        await restoredService.finishPendingWrites()
        let afterDisable = try files()
        precondition(afterDisable.count == 3)
        let duplicates = try DateBackupFile.write(JSONEncoder().encode([initial, initial]), in: root)
        do { _ = try await restoredService.preview(duplicates); preconditionFailure("Duplicate IDs are invalid") } catch {}
        let actual = try CustomSpecialDateStore.loadChecked(preferences: source)
        precondition(actual == [initial])

        let local = source.directory.appendingPathComponent("customSpecialDates.plist")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: local.path)
        try restoredService.chooseFolder(folder)
        await restoredService.finishPendingWrites()
        let afterDenied = try files()
        precondition(restoredService.errorMessage != nil && afterDenied.count == 3)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: local.path)
        let damaged = Data("damaged local date file".utf8)
        try damaged.write(to: local)
        let repair = try await restoredService.preview(first[0])
        precondition(repair.previousCount == nil)
        let retained = try restoredService.restore(repair)!
        let raw = try Data(contentsOf: retained)
        let repaired = try CustomSpecialDateStore.loadChecked(preferences: source)
        precondition(raw == damaged && repaired == [initial])
        print("PASS: folder grant, immutable snapshots, burst edits, relaunch, manual restore, rollback, stale previews, invalid files, permission failures and opt-out")
    }
}
