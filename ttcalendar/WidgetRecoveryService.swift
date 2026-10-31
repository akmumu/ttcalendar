import AppKit
import Combine
import Darwin

nonisolated struct WidgetProcessIdentity: Equatable, Sendable {
    let pid: Int32
    let executablePath: String
    let userID: UInt32
    let startSeconds: UInt64
    let startMicroseconds: UInt64
}

nonisolated protocol WidgetProcessAccess {
    func processes() throws -> [WidgetProcessIdentity]
    func identity(for pid: Int32) -> WidgetProcessIdentity?
    func sendSignal(_ signal: Int32, to pid: Int32) throws
}

nonisolated struct SystemWidgetProcesses: WidgetProcessAccess {
    func processes() throws -> [WidgetProcessIdentity] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { throw POSIXError(.EPERM) }
        var pids = [Int32](repeating: 0, count: Int(count) + 128)
        let bytes = Int32(pids.count * MemoryLayout<Int32>.size)
        let actual = proc_listallpids(&pids, bytes)
        guard actual > 0 else { throw POSIXError(.EPERM) }
        return pids.prefix(min(Int(actual), pids.count)).compactMap { identity(for: $0) }
    }

    func identity(for pid: Int32) -> WidgetProcessIdentity? {
        guard pid > 0 else { return nil }
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size,
              info.pbi_status != SZOMB else { return nil }
        // PROC_PIDPATHINFO_MAXSIZE is a C expression macro not imported by Swift.
        var path = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(pid, &path, UInt32(path.count)) > 0 else { return nil }
        return WidgetProcessIdentity(pid: pid,
                                     executablePath: URL(fileURLWithPath: String(cString: path)).resolvingSymlinksInPath().path,
                                     userID: info.pbi_uid,
                                     startSeconds: info.pbi_start_tvsec,
                                     startMicroseconds: info.pbi_start_tvusec)
    }

    func sendSignal(_ signal: Int32, to pid: Int32) throws {
        guard kill(pid, signal) == 0 || errno == ESRCH else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EPERM)
        }
    }
}

nonisolated enum WidgetProcessRestarter {
    static func stop(
        executableURL: URL,
        userID: UInt32 = getuid(),
        processes: WidgetProcessAccess = SystemWidgetProcesses(),
        pause: () async throws -> Void = { try await Task.sleep(nanoseconds: 500_000_000) }
    ) async throws -> Int {
        let path = executableURL.resolvingSymlinksInPath().path
        let matches = try processes.processes().filter {
            $0.userID == userID && $0.executablePath == path && $0.pid != getpid()
        }
        // Match the full executable path, current user and process start time.
        // Apple's Calendar widget has the same executable name as ours.
        for process in matches where processes.identity(for: process.pid) == process {
            try processes.sendSignal(SIGTERM, to: process.pid)
        }
        if !matches.isEmpty { try await pause() }
        for process in matches where processes.identity(for: process.pid) == process {
            try processes.sendSignal(SIGKILL, to: process.pid)
        }
        if !matches.isEmpty { try await pause() }
        if matches.contains(where: { processes.identity(for: $0.pid) == $0 }) {
            throw POSIXError(.EBUSY)
        }
        return matches.count
    }
}

@MainActor
final class WidgetRecoveryService: ObservableObject {
    static let shared = WidgetRecoveryService()

    @Published private(set) var isRestarting = false
    @Published private(set) var message: String?
    @Published private(set) var hasError = false

    enum Target { case calendarWidget, systemWidgets }

    func restart(_ target: Target = .calendarWidget) {
        guard !isRestarting else { return }
        let executable: URL
        switch target {
        case .calendarWidget:
            guard let plugins = Bundle.main.builtInPlugInsURL else { return }
            executable = plugins.appendingPathComponent("CalendarWidgetExtension.appex/Contents/MacOS/CalendarWidgetExtension")
        case .systemWidgets:
            executable = URL(fileURLWithPath: "/System/Library/CoreServices/NotificationCenter.app/Contents/MacOS/NotificationCenter")
        }
        isRestarting = true
        hasError = false
        message = target == .calendarWidget ? "正在重启抬头日历小组件…" : "正在重启系统小组件服务…"
        Task {
            do {
                let count = try await Task.detached {
                    try await WidgetProcessRestarter.stop(executableURL: executable)
                }.value
                AppInstallRefreshCoordinator.reloadWidgetsRepeatedly()
                message = count == 0
                    ? "未发现运行中的进程，已请求系统加载小组件。若仍卡住，可重启系统小组件服务。"
                    : "已结束原进程并请求系统重新加载。恢复显示可能需要几秒；日期数据已保留。"
            } catch {
                hasError = true
                message = "未能完成重启：\(error.localizedDescription)"
            }
            isRestarting = false
        }
    }
}
