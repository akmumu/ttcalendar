import Foundation

/// Pure date calculation, separate from permissions and the notification center.
enum DateReminderPlan {
    static let identifierPrefix = "custom-date-reminder."
    // Leap-sensitive reminders need concrete years instead of an annual trigger.
    static let lookaheadYears = 8
    static let requestLimit = 60

    struct Item {
        let identifier: String
        let dateID: UUID
        let name: String
        let daysBefore: Int
        let fireDate: Date
        let components: DateComponents
        let repeats: Bool

        var body: String {
            daysBefore == 0 ? "今天是\(name)" : "距离\(name)还有 \(daysBefore) 天"
        }
    }

    static func items(for dates: [CustomSpecialDate], now: Date = Date(), timeZone: TimeZone = .autoupdatingCurrent) -> [Item] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let currentYear = calendar.component(.year, from: now)
        var result: [Item] = []

        for date in dates {
            guard let reminder = date.reminder else { continue }
            for offset in reminder.offsets {
                let repeats = date.isYearly && canRepeatAnnually(date, daysBefore: offset, calendar: calendar)
                let years = date.isYearly ? Array(currentYear...(currentYear + lookaheadYears)) : [date.year].compactMap { $0 }
                for year in years {
                    guard let occurrence = exactDate(year: year, month: date.month, day: date.day, calendar: calendar),
                          let reminderDay = calendar.date(byAdding: .day, value: -offset, to: occurrence),
                          let fireDate = calendar.date(bySettingHour: reminder.hour, minute: reminder.minute, second: 0,
                                                       of: reminderDay, matchingPolicy: .nextTime, repeatedTimePolicy: .first),
                          fireDate > now else { continue }

                    var components = calendar.dateComponents([.month, .day, .hour, .minute, .second], from: fireDate)
                    // Keep wall-clock time local; rebuilding on activation also handles time-zone changes.
                    components.calendar = Calendar(identifier: .gregorian)
                    if repeats {
                        components.hour = reminder.hour
                        components.minute = reminder.minute
                    } else {
                        components.year = calendar.component(.year, from: fireDate)
                    }
                    let suffix = repeats ? "annual" : String(year)
                    result.append(Item(
                        identifier: "\(identifierPrefix)\(date.id.uuidString).\(offset).\(suffix)",
                        dateID: date.id, name: date.name, daysBefore: offset,
                        fireDate: fireDate, components: components, repeats: repeats
                    ))
                    if repeats { break }
                }
            }
        }
        return result.sorted {
            $0.fireDate == $1.fireDate ? $0.identifier < $1.identifier : $0.fireDate < $1.fireDate
        }
    }

    private static func exactDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        let actual = calendar.dateComponents([.year, .month, .day], from: date)
        return actual.year == year && actual.month == month && actual.day == day ? date : nil
    }

    private static func canRepeatAnnually(_ date: CustomSpecialDate, daysBefore: Int, calendar: Calendar) -> Bool {
        // UNCalendarNotificationTrigger can normalize an annual February 29 to March 1.
        // Use valid concrete leap years for both same-day and advance notifications.
        if date.month == 2 && date.day == 29 { return false }
        var monthDays = Set<String>()
        for year in [2000, 2001] {
            guard let occurrence = exactDate(year: year, month: date.month, day: date.day, calendar: calendar),
                  let fireDay = calendar.date(byAdding: .day, value: -daysBefore, to: occurrence) else { return false }
            monthDays.insert("\(calendar.component(.month, from: fireDay))-\(calendar.component(.day, from: fireDay))")
        }
        return monthDays.count == 1
    }
}
