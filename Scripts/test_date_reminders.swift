import Foundation
import UserNotifications

@main
struct DateReminderTests {
    static let zone = TimeZone(identifier: "Asia/Shanghai")!
    static var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = zone
        return result
    }

    static func instant(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    static func event(_ year: Int? = nil, _ month: Int, _ day: Int,
                      reminder: DateReminder? = DateReminder()) -> CustomSpecialDate {
        CustomSpecialDate(year: year, month: month, day: day, type: .birthday,
                          name: "生日", isYearly: year == nil, reminder: reminder)
    }

    static func plan(_ date: CustomSpecialDate, now: Date) -> [DateReminderPlan.Item] {
        DateReminderPlan.items(for: [date], now: now, timeZone: zone)
    }

    static func main() throws {
        let now = instant(2026, 9, 29, 10)
        let legacy = """
        {"id":"00000000-0000-0000-0000-000000000001","month":10,"day":1,"type":"生日","customLabel":"生","name":"生日","isYearly":true}
        """.data(using: .utf8)!
        let decodedLegacy = try JSONDecoder().decode(CustomSpecialDate.self, from: legacy)
        precondition(decodedLegacy.reminder == nil)
        let original = event(2026, 10, 1, reminder: DateReminder(daysBefore: 3, hour: 8, minute: 30))
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CustomSpecialDate.self, from: encoded)
        precondition(decoded == original)

        precondition(plan(event(2026, 10, 1, reminder: nil), now: now).isEmpty)
        precondition(plan(event(2026, 9, 29), now: now).isEmpty, "Don't replay today's past reminder")
        let laterToday = plan(event(2026, 9, 29, reminder: DateReminder(hour: 11)), now: now)
        precondition(laterToday.count == 1 && laterToday[0].fireDate == instant(2026, 9, 29, 11))
        let elapsedAdvance = plan(original, now: now)
        precondition(elapsedAdvance.count == 1 && elapsedAdvance[0].daysBefore == 0)
        precondition(elapsedAdvance[0].fireDate == instant(2026, 10, 1, 8, 30))
        precondition(!elapsedAdvance[0].repeats)

        let birthday = event(nil, 10, 5, reminder: DateReminder(daysBefore: 3))
        let yearly = plan(birthday, now: now)
        precondition(yearly.count == 2 && yearly.allSatisfy(\.repeats))
        precondition(yearly[0].fireDate == instant(2026, 10, 2, 9))
        precondition(yearly[1].fireDate == instant(2026, 10, 5, 9))
        precondition(yearly.allSatisfy { $0.components.year == nil })
        precondition(plan(event(nil, 9, 29), now: now)[0].fireDate == instant(2027, 9, 29, 9))

        let newYear = plan(event(nil, 1, 1, reminder: DateReminder(daysBefore: 3, alsoOnDay: false)), now: now)
        precondition(newYear.count == 1 && newYear[0].fireDate == instant(2026, 12, 29, 9))
        let oneOffNewYear = plan(event(2027, 1, 1, reminder: DateReminder(daysBefore: 7)), now: now)
        precondition(oneOffNewYear[0].components.year == 2026)

        let leap = plan(event(nil, 2, 29, reminder: DateReminder(daysBefore: 1)), now: now)
        precondition(event(nil, 2, 29).nextOccurrence(onOrAfter: now, calendar: calendar) == instant(2028, 2, 29))
        let leapAdvance = leap.filter { $0.daysBefore == 1 }
        precondition(leapAdvance.count == 2 && leapAdvance.allSatisfy { !$0.repeats })
        precondition(leapAdvance[0].fireDate == instant(2028, 2, 28, 9))
        precondition(leapAdvance[1].fireDate == instant(2032, 2, 28, 9))
        let leapOnDay = leap.first { $0.daysBefore == 0 }!
        precondition(!leapOnDay.repeats && leapOnDay.components.year == 2028 && leapOnDay.components.month == 2 && leapOnDay.components.day == 29)
        precondition(plan(event(2027, 2, 29), now: now).isEmpty, "Invalid dates must not roll into March")

        let march = plan(event(nil, 3, 1, reminder: DateReminder(daysBefore: 1, alsoOnDay: false)), now: now)
        precondition(march.allSatisfy { !$0.repeats })
        precondition(march[0].fireDate == instant(2027, 2, 28, 9))
        precondition(march[1].fireDate == instant(2028, 2, 29, 9))

        var edited = birthday
        edited.name = "新名称"
        edited.reminder?.hour = 15
        let changed = plan(edited, now: now)
        precondition(changed.map(\.identifier) == yearly.map(\.identifier), "Edit replaces existing IDs")
        precondition(changed.allSatisfy { $0.components.hour == 15 && $0.body.contains("新名称") })
        edited.reminder = nil
        precondition(plan(edited, now: now).isEmpty)
        precondition(DateReminderPlan.items(for: [], now: now).isEmpty)
        precondition(plan(event(nil, 10, 1, reminder: DateReminder(daysBefore: -1)), now: now).isEmpty)

        let many = (1...100).map { event(2027, 1, 1 + ($0 % 28)) }
        let queue = DateReminderPlan.items(for: many, now: now, timeZone: zone)
        precondition(zip(queue, queue.dropFirst()).allSatisfy { $0.fireDate <= $1.fireDate })
        precondition(Set(queue.map(\.identifier)).count == 100)

        let la = TimeZone(identifier: "America/Los_Angeles")!
        let dst = DateReminderPlan.items(for: [event(2027, 3, 14, reminder: DateReminder(hour: 2, minute: 30))],
                                        now: now, timeZone: la)
        var laCalendar = Calendar(identifier: .gregorian)
        laCalendar.timeZone = la
        precondition(laCalendar.component(.day, from: dst[0].fireDate) == 14)
        precondition(laCalendar.component(.hour, from: dst[0].fireDate) == 3, "Spring gap uses next available time")
        let annualDST = DateReminderPlan.items(for: [event(nil, 3, 14, reminder: DateReminder(hour: 2, minute: 30))],
                                              now: now, timeZone: la)
        precondition(annualDST[0].components.hour == 2 && annualDST[0].components.minute == 30)

        // Exercise actual system trigger construction without asking permission or sending notifications.
        for item in yearly + leap + march {
            let trigger = UNCalendarNotificationTrigger(dateMatching: item.components, repeats: item.repeats)
            let fireDate = trigger.nextTriggerDate()!
            let actual = Calendar(identifier: .gregorian).dateComponents([.month, .day], from: fireDate)
            precondition(actual.month == item.components.month && actual.day == item.components.day,
                         "System triggers must not normalize February 29 to March 1")
        }
        print("PASS: legacy data, persistence, opt-out, past times, annual recurrence, cross-year, leap days, edits, ordering, DST and system triggers")
    }
}
