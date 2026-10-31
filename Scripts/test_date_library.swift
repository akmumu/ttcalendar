import Foundation

@MainActor enum AppInstallRefreshCoordinator { static func reloadWidgetsRepeatedly() {} }
@MainActor final class DateReminderService { static let shared = DateReminderService(); func refresh() {} }

@main
struct DateLibraryTests {
    static func reject(_ action: () throws -> Void) {
        do { try action(); preconditionFailure("Expected operation to be rejected") } catch {}
    }

    @MainActor static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let defaults = UserDefaults(suiteName: root.lastPathComponent)!
        defer {
            CustomSpecialDateStore.library = nil
            defaults.removePersistentDomain(forName: root.lastPathComponent)
            try? FileManager.default.removeItem(at: root)
        }
        let widget = WidgetPreferences(directory: root.appendingPathComponent("widget"))
        let manager = DateLibrary(defaults: defaults, widget: widget)
        let a = root.appendingPathComponent("old"), b = root.appendingPathComponent("new")
        for dir in [a, b] { try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) }
        let original = CustomSpecialDate(month: 5, day: 4, type: .birthday, name: "Library fixture", reminder: DateReminder())
        let data = try JSONEncoder().encode([original])
        let raw = try PropertyListSerialization.data(fromPropertyList: ["value": data], format: .binary, options: 0)
        let old = FolderDateFile(folder: a), new = FolderDateFile(folder: b)
        try old.replace(raw, expecting: nil)
        try manager.select(a, create: false)
        try manager.select(b, create: true)
        let copy = try new.read()
        precondition(copy == raw)
        reject { try manager.select(b, create: true) }
        var edited = original
        edited.name = "Changed"
        try CustomSpecialDateStore.update(edited, original: original)
        _ = manager.refresh()
        let local = try old.read()
        let edits = try CustomSpecialDateStore.records(in: new.read())
        let snapshot = try JSONDecoder().decode([CustomSpecialDate].self, from: widget.readData(forKey: CustomSpecialDateStore.widgetSnapshotKey)!)
        precondition(local == raw && edits == [edited] && snapshot == edits)
        reject { try new.replace(raw, expecting: raw) }
        reject { try CustomSpecialDateStore.update(original, original: original) }
        try new.replace(raw, expecting: new.read())
        precondition(manager.refresh())
        let refreshed = try CustomSpecialDateStore.loadChecked()
        precondition(refreshed == [original])
        let reopen = DateLibrary(defaults: defaults, widget: widget)
        CustomSpecialDateStore.library = nil
        reopen.resume()
        let restoredFolder = URL(fileURLWithPath: reopen.path).resolvingSymlinksInPath()
        precondition(restoredFolder.path == b.resolvingSymlinksInPath().path, "Restored \(restoredFolder.path), expected \(b.path)")
        try CustomSpecialDateStore.delete(original)
        let empty = try CustomSpecialDateStore.records(in: new.read())
        precondition(empty.isEmpty)
        try FileManager.default.removeItem(at: b.appendingPathComponent(FolderDateFile.filename))
        reject { try CustomSpecialDateStore.add(original) }
        reject { _ = try CustomSpecialDateStore.loadChecked() }
        try Data("broken".utf8).write(to: b.appendingPathComponent(FolderDateFile.filename))
        reject { try reopen.select(b, create: false) }
        reject { try CustomSpecialDateStore.add(original) }
        _ = reopen.refresh()
        precondition(reopen.issue != nil)
        // An empty or missing target never replaces the active library.
        try reopen.select(a, create: false)
        reject { try reopen.select(root, create: false) }
        let kept = try CustomSpecialDateStore.loadChecked()
        precondition(kept == [original] && reopen.path == a.path)
        print("PASS: open in place, save as, no overwrite, authoritative CRUD, widget copy, external changes, stale edits, bookmark restart and unavailable/corrupt library")
    }
}
