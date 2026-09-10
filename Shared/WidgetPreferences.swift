import Foundation
import os

// One atomic file per setting prevents the app and widget from overwriting
// unrelated values when they update at the same time.
final class WidgetPreferences {
    static let extensionIdentifier = "akmumu.ttcalendar.CalendarWidget"
    static let shared = WidgetPreferences(directory: storageDirectory)
    private let directory: URL
    private(set) var lastWriteError: String?
    private let logger = Logger(subsystem: "akmumu.ttcalendar", category: "WidgetStorage")

    init(directory: URL) {
        self.directory = directory
    }

    private static var storageDirectory: URL {
        let manager = FileManager.default
        if Bundle.main.bundleIdentifier == extensionIdentifier {
            return manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("ttcalendar", isDirectory: true)
        }
        return manager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/\(extensionIdentifier)/Data/Library/Application Support/ttcalendar", isDirectory: true)
    }

    func data(forKey key: String) -> Data? { value(forKey: key) as? Data }
    func string(forKey key: String) -> String? { value(forKey: key) as? String }
    func integer(forKey key: String) -> Int { (value(forKey: key) as? NSNumber)?.intValue ?? 0 }
    func double(forKey key: String) -> Double { (value(forKey: key) as? NSNumber)?.doubleValue ?? 0 }

    @discardableResult
    func set(_ value: Any, forKey key: String) -> Bool {
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: ["value": value], format: .binary, options: 0)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: fileURL(key), options: .atomic)
            lastWriteError = nil
            return true
        } catch {
            lastWriteError = error.localizedDescription
            logger.error("Cannot write widget setting \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func value(forKey key: String) -> Any? {
        do {
            let data = try Data(contentsOf: fileURL(key))
            let values = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
            return values?["value"]
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        } catch {
            logger.error("Cannot read widget setting \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func fileURL(_ key: String) -> URL {
        precondition(!key.contains("/") && !key.contains(".."))
        return directory.appendingPathComponent(key).appendingPathExtension("plist")
    }

    // Only the non-sandboxed host migrates the old App Group. The extension
    // never attempts to access that protected directory in ad-hoc builds.
    func migrateLegacyData(from legacyGroup: URL? = nil) {
        guard Bundle.main.bundleIdentifier != Self.extensionIdentifier else { return }
        let keys = ["cachedHolidayEvents", "customSpecialDates"]
        guard keys.contains(where: { !FileManager.default.fileExists(atPath: fileURL($0).path) }) else { return }
        let group = legacyGroup ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers/group.akmumu.ttcalendar", isDirectory: true)
        let preferences = group.appendingPathComponent("Library/Preferences/group.akmumu.ttcalendar.plist")
        do {
            let json = group.appendingPathComponent("cachedHolidayEvents.json")
            if !FileManager.default.fileExists(atPath: fileURL("cachedHolidayEvents").path),
               FileManager.default.fileExists(atPath: json.path) {
                let data = try Data(contentsOf: json)
                _ = try JSONSerialization.jsonObject(with: data)
                set(data, forKey: "cachedHolidayEvents")
            }
            guard FileManager.default.fileExists(atPath: preferences.path) else { return }
            let data = try Data(contentsOf: preferences)
            let old = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
            for key in keys where !FileManager.default.fileExists(atPath: fileURL(key).path) {
                if let value = old?[key] as? Data {
                    set(value, forKey: key)
                }
            }
        } catch {
            logger.error("Cannot migrate legacy widget data: \(error.localizedDescription, privacy: .public)")
        }
    }
}
