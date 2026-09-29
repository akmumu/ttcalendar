import Foundation
import UserNotifications

@MainActor
private final class FakeNotificationCenter: DateReminderNotificationCenter {
    var delegate: UNUserNotificationCenterDelegate?
    var status: UNAuthorizationStatus = .authorized
    var requests: [String: UNNotificationRequest] = [:]
    var failAdds = false
    var authorizationRequests = 0
    var delayNextRead = false

    func reminderAuthorizationStatus() async -> UNAuthorizationStatus { status }
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationRequests += 1
        status = .authorized
        return true
    }
    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        if delayNextRead {
            delayNextRead = false
            await Task.yield()
        }
        return Array(requests.values)
    }
    func deliveredNotifications() async -> [UNNotification] { [] }
    func add(_ request: UNNotificationRequest) async throws {
        if failAdds { throw NSError(domain: "TestNotificationFailure", code: 1) }
        requests[request.identifier] = request
    }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        for id in identifiers { requests[id] = nil }
    }
    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {}
}

@main
struct ReminderServiceTests {
    @MainActor
    static func main() async {
        let center = FakeNotificationCenter()
        var dates = [CustomSpecialDate(month: 10, day: 5, type: .birthday, name: "生日",
                                       reminder: DateReminder(daysBefore: 3))]
        let service = DateReminderService(center: center, loadDates: { dates })
        service.start()
        await service.finishPendingUpdates()
        precondition(center.requests.count == 2 && center.authorizationRequests == 0)

        dates[0].name = "纪念日"
        dates[0].reminder?.hour = 17
        service.refresh()
        await service.finishPendingUpdates()
        precondition(center.requests.count == 2)
        precondition(center.requests.values.allSatisfy {
            $0.content.title == "纪念日" && ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents.hour == 17
        })

        let unrelated = UNNotificationRequest(identifier: "unrelated", content: UNMutableNotificationContent(), trigger: nil)
        center.requests[unrelated.identifier] = unrelated
        dates[0].reminder = nil
        service.refresh()
        await service.finishPendingUpdates()
        precondition(Array(center.requests.keys) == ["unrelated"], "Only remove owned notifications")

        dates[0].reminder = DateReminder()
        center.status = .denied
        service.refresh()
        await service.finishPendingUpdates()
        precondition(center.requests.count == 1 && service.statusMessage?.contains("尚未安排") == true)
        await service.requestAuthorization()
        precondition(center.authorizationRequests == 0, "Don't prompt again after denial")

        center.status = .notDetermined
        await service.requestAuthorization()
        precondition(center.authorizationRequests == 1)
        service.refresh()
        await service.finishPendingUpdates()
        precondition(center.requests.count == 2)

        center.failAdds = true
        dates[0].reminder?.hour = 18
        service.refresh()
        await service.finishPendingUpdates()
        precondition(service.errorMessage != nil && center.requests.count == 1, "Failed edit must remove old time")
        center.failAdds = false
        service.refresh()
        await service.finishPendingUpdates()
        precondition(service.errorMessage == nil && center.requests.count == 2)

        center.delayNextRead = true
        service.refresh()
        await Task.yield()
        dates = []
        service.refresh()
        precondition(service.isUpdating)
        await service.finishPendingUpdates()
        precondition(center.requests.count == 1 && !service.isUpdating, "Later deletion wins overlapping refreshes")

        dates = (0..<70).map { _ in
            CustomSpecialDate(month: 10, day: 5, type: .birthday, name: "生日", reminder: DateReminder())
        }
        service.refresh()
        await service.finishPendingUpdates()
        precondition(center.requests.count == DateReminderPlan.requestLimit)
        precondition(service.statusMessage?.contains("续排") == true)
        print("PASS: permission flow, edit replacement, opt-out, deletion, failures/retry, serialization, capacity and unrelated request preservation")
    }
}
