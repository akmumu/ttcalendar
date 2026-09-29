import AppKit
import Combine
import UserNotifications

@MainActor
protocol DateReminderNotificationCenter: AnyObject {
    var delegate: UNUserNotificationCenterDelegate? { get set }
    func reminderAuthorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func deliveredNotifications() async -> [UNNotification]
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: DateReminderNotificationCenter {
    func reminderAuthorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }
}

@MainActor
final class DateReminderService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = DateReminderService()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var statusMessage: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isUpdating = false
    private let center: DateReminderNotificationCenter
    private let loadDates: @MainActor () -> [CustomSpecialDate]
    private var pendingTask: Task<Void, Never>?
    private var pendingUpdateCount = 0

    init(center: DateReminderNotificationCenter = UNUserNotificationCenter.current(),
         loadDates: @escaping @MainActor () -> [CustomSpecialDate] = CustomSpecialDateStore.load) {
        self.center = center
        self.loadDates = loadDates
        super.init()
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    func start() {
        center.delegate = self
        refresh()
    }

    func updateAuthorization() async {
        authorizationStatus = await center.reminderAuthorizationStatus()
    }

    func requestAuthorization() async {
        await updateAuthorization()
        guard authorizationStatus == .notDetermined else { return }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
            errorMessage = nil
        } catch {
            errorMessage = "无法申请通知权限：\(error.localizedDescription)"
        }
        await updateAuthorization()
    }

    func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Serialize rebuilds so an older asynchronous save cannot restore deleted reminders.
    func refresh() {
        pendingUpdateCount += 1
        isUpdating = true
        let previous = pendingTask
        pendingTask = Task {
            await previous?.value
            await rebuild()
            pendingUpdateCount -= 1
            isUpdating = pendingUpdateCount > 0
        }
    }

    func finishPendingUpdates() async {
        await pendingTask?.value
    }

    private func rebuild() async {
        await updateAuthorization()
        let dates = loadDates()
        let allItems = DateReminderPlan.items(for: dates)
        let pending = await center.pendingNotificationRequests()
        let ownPending = pending.filter { $0.identifier.hasPrefix(DateReminderPlan.identifierPrefix) }
        let capacity = max(0, DateReminderPlan.requestLimit - (pending.count - ownPending.count))
        let items = isAuthorized ? Array(allItems.prefix(capacity)) : []
        let wantedIDs = Set(items.map(\.identifier))
        center.removePendingNotificationRequests(withIdentifiers: ownPending.map(\.identifier).filter { !wantedIDs.contains($0) })

        // Editing, disabling, or deleting a date also clears obsolete delivered alerts.
        let delivered = await center.deliveredNotifications()
        let currentDates = Dictionary(uniqueKeysWithValues: dates.map { ($0.id.uuidString, $0) })
        let staleDelivered = delivered.compactMap { notification -> String? in
            let request = notification.request
            guard request.identifier.hasPrefix(DateReminderPlan.identifierPrefix) else { return nil }
            guard let id = request.content.userInfo["dateID"] as? String,
                  let date = currentDates[id], date.reminder != nil,
                  request.content.userInfo["signature"] as? String == signature(for: date) else {
                return request.identifier
            }
            return nil
        }
        center.removeDeliveredNotifications(withIdentifiers: staleDelivered)

        errorMessage = nil
        guard isAuthorized else {
            statusMessage = dates.contains(where: { $0.reminder != nil })
                ? "提醒设置已保存，尚未安排通知。请在系统设置中允许抬头日历发送通知。" : nil
            return
        }

        var scheduled = 0
        for item in items {
            let content = UNMutableNotificationContent()
            content.title = item.name
            content.body = item.body
            content.sound = .default
            content.threadIdentifier = item.dateID.uuidString
            content.userInfo = ["dateID": item.dateID.uuidString,
                                "signature": currentDates[item.dateID.uuidString].map(signature(for:)) ?? ""]
            let trigger = UNCalendarNotificationTrigger(dateMatching: item.components, repeats: item.repeats)
            do {
                try await center.add(UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger))
                scheduled += 1
            } catch {
                center.removePendingNotificationRequests(withIdentifiers: [item.identifier])
                errorMessage = "部分提醒未能安排，请重试：\(error.localizedDescription)"
            }
        }

        if allItems.count > capacity {
            statusMessage = "已优先安排最近的 \(scheduled) 条提醒；其余提醒需再次打开应用续排。"
        } else if dates.contains(where: { $0.reminder != nil }) {
            statusMessage = scheduled == 0 ? "所选提醒时间已过，暂无待发送通知。" : "已安排 \(scheduled) 条提醒，应用关闭后仍可通知。"
        } else {
            statusMessage = nil
        }
    }

    private func signature(for date: CustomSpecialDate) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(date).base64EncodedString()) ?? ""
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                           willPresent notification: UNNotification,
                                           withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}
