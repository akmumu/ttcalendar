import Foundation

enum AppInstallRefreshCoordinator { static func reloadWidgetsRepeatedly() {} }

@main
struct WidgetRecoveryProcessTest {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let executable = root.appendingPathComponent("CalendarWidgetExtension")
        try FileManager.default.copyItem(at: URL(fileURLWithPath: "/bin/sleep"), to: executable)
        let child = Process()
        child.executableURL = executable
        child.arguments = ["30"]
        let unrelated = Process()
        unrelated.executableURL = URL(fileURLWithPath: "/bin/sleep")
        unrelated.arguments = ["30"]
        try child.run()
        try unrelated.run()
        defer {
            if child.isRunning { child.terminate() }
            if unrelated.isRunning { unrelated.terminate() }
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        let count = try await WidgetProcessRestarter.stop(executableURL: executable)
        child.waitUntilExit()
        precondition(count == 1 && !child.isRunning && unrelated.isRunning)
        precondition(child.terminationReason == .uncaughtSignal)
        print("PASS: real process terminated by exact executable path; unrelated process remains alive")
    }
}
