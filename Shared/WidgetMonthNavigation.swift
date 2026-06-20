import Foundation

enum WidgetMonthNavigation {
    private static let monthOffsetKey = "widgetMonthOffset"
    private static let minimumOffset = -12
    private static let maximumOffset = 12

    static var currentOffset: Int {
        userDefaults.integer(forKey: monthOffsetKey)
    }

    static var currentMonthAnchor: Date {
        CalendarContent.addingMonths(currentOffset, to: Date())
    }

    @discardableResult
    static func move(by value: Int) -> Int {
        let offset = min(max(currentOffset + value, minimumOffset), maximumOffset)
        userDefaults.set(offset, forKey: monthOffsetKey)
        return offset
    }

    static func reset() {
        userDefaults.set(0, forKey: monthOffsetKey)
    }

    private static var userDefaults: UserDefaults {
        UserDefaults(suiteName: CalendarEventCache.appGroupIdentifier) ?? .standard
    }
}
