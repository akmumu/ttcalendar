import Foundation
import Darwin

// The UI coordinator is supplied by the app target in production.
enum AppInstallRefreshCoordinator { static func reloadWidgetsRepeatedly() {} }

private final class FakeProcesses: WidgetProcessAccess {
    var running: [Int32: WidgetProcessIdentity] = [:]
    var signals: [(Int32, Int32)] = []
    var ignoresTerminate = false
    var deniesSignals = false
    var onSignal: ((Int32, Int32) -> Void)?

    func processes() throws -> [WidgetProcessIdentity] { Array(running.values) }
    func identity(for pid: Int32) -> WidgetProcessIdentity? { running[pid] }
    func sendSignal(_ signal: Int32, to pid: Int32) throws {
        if deniesSignals { throw POSIXError(.EPERM) }
        signals.append((pid, signal))
        if signal == SIGKILL || !ignoresTerminate { running[pid] = nil }
        onSignal?(pid, signal)
    }
}

@main
struct WidgetRecoveryTests {
    static func main() async throws {
        let ownPath = "/Applications/抬头日历.app/Contents/PlugIns/CalendarWidgetExtension.appex/Contents/MacOS/CalendarWidgetExtension"
        let otherPath = "/System/Applications/Calendar.app/Contents/PlugIns/CalendarWidgetExtension.appex/Contents/MacOS/CalendarWidgetExtension"
        func identity(_ pid: Int32, path: String = ownPath, user: UInt32 = 501, started: UInt64 = 1) -> WidgetProcessIdentity {
            WidgetProcessIdentity(pid: pid, executablePath: path, userID: user, startSeconds: started, startMicroseconds: 0)
        }
        let access = FakeProcesses()
        access.running = [900001: identity(900001), 900002: identity(900002, path: otherPath), 900003: identity(900003, user: 502)]
        let count = try await WidgetProcessRestarter.stop(executableURL: URL(fileURLWithPath: ownPath), userID: 501, processes: access, pause: {})
        precondition(count == 1 && access.signals.count == 1 && access.signals[0].0 == 900001)
        precondition(access.running.count == 2, "Never kill Apple's identically named widget or another user's process")

        access.running[900001] = identity(900001)
        access.ignoresTerminate = true
        access.signals = []
        _ = try await WidgetProcessRestarter.stop(executableURL: URL(fileURLWithPath: ownPath), userID: 501, processes: access, pause: {})
        precondition(access.signals.map(\.1) == [SIGTERM, SIGKILL], "Force only the verified hung process")

        access.running[900001] = identity(900001)
        access.signals = []
        access.onSignal = { pid, signal in
            if signal == SIGTERM { access.running[pid] = identity(pid, started: 2) }
        }
        _ = try await WidgetProcessRestarter.stop(executableURL: URL(fileURLWithPath: ownPath), userID: 501, processes: access, pause: {})
        precondition(access.signals.count == 1, "A recycled PID must not receive SIGKILL")

        access.onSignal = nil
        access.deniesSignals = true
        do {
            _ = try await WidgetProcessRestarter.stop(executableURL: URL(fileURLWithPath: ownPath), userID: 501, processes: access, pause: {})
            preconditionFailure("Permission error was swallowed")
        } catch let error as POSIXError {
            precondition(error.code == .EPERM)
        }
        access.running = [:]
        let missing = try await WidgetProcessRestarter.stop(executableURL: URL(fileURLWithPath: ownPath), processes: access, pause: {})
        precondition(missing == 0)
        print("PASS: exact path/user targeting, graceful/forced stop, PID reuse, denied signals and absent processes")
    }
}
