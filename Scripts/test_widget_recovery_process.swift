import Foundation

enum AppInstallRefreshCoordinator { static func reloadWidgetsRepeatedly() {} }

@main
struct WidgetRecoveryProcessTest {
    static func main() async throws {
        if CommandLine.arguments.dropFirst().first == "--fixture" {
            sleep(60)
            return
        }
        let fixture = URL(fileURLWithPath: CommandLine.arguments[0])
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let executable = root.appendingPathComponent("CalendarWidgetExtension")
        try FileManager.default.copyItem(at: fixture, to: executable)
        let child = Process()
        child.executableURL = executable
        child.arguments = ["--fixture"]
        let otherFolder = root.appendingPathComponent("AnotherApp")
        try FileManager.default.createDirectory(at: otherFolder, withIntermediateDirectories: true)
        let otherExecutable = otherFolder.appendingPathComponent(executable.lastPathComponent)
        try FileManager.default.copyItem(at: fixture, to: otherExecutable)
        let unrelated = Process()
        unrelated.executableURL = otherExecutable
        unrelated.arguments = ["--fixture"]
        try child.run()
        try unrelated.run()
        defer {
            if child.isRunning { child.terminate() }
            if unrelated.isRunning { unrelated.terminate() }
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        // Sparkle moves aside the running image, installs a new binary at the
        // original path, then removes the old one while its process is alive.
        let staging = root.appendingPathComponent("Installation")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let old = staging.appendingPathComponent(executable.lastPathComponent)
        try FileManager.default.moveItem(at: executable, to: old)
        try FileManager.default.copyItem(at: fixture, to: executable)
        let processes = SystemWidgetProcesses(targetURL: executable, stagingDirectory: staging.resolvingSymlinksInPath())
        precondition(processes.identity(for: child.processIdentifier) != nil, "Moved image")
        try FileManager.default.removeItem(at: old)
        precondition(processes.identity(for: child.processIdentifier) != nil, "Unlinked image")
        let count = try await WidgetProcessRestarter.stop(executableURL: executable, processes: processes)
        child.waitUntilExit()
        precondition(count == 1 && !child.isRunning && unrelated.isRunning)
        precondition(child.terminationReason == .uncaughtSignal)
        print("PASS: replaced and unlinked executable recovered by its original path; identically named process remains alive")
    }
}
