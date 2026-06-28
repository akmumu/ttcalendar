import Foundation

enum WidgetMonthNavigation {
    private static let monthOffsetKey = "widgetMonthOffset"
    private static let lastInteractionKey = "widgetMonthLastInteraction"
    private static let minimumOffset = -12
    private static let maximumOffset = 12
    private static let interactionWindow: TimeInterval = 10

    static var currentOffset: Int {
        userDefaults.integer(forKey: monthOffsetKey)
    }

    static var hasRecentInteraction: Bool {
        let lastInteraction = userDefaults.double(forKey: lastInteractionKey)
        guard lastInteraction > 0 else {
            return false
        }

        return Date().timeIntervalSinceReferenceDate - lastInteraction < interactionWindow
    }

    static var currentMonthAnchor: Date {
        currentMonthAnchor(for: Date())
    }

    static func currentMonthAnchor(for date: Date) -> Date {
        CalendarContent.addingMonths(currentOffset, to: date)
    }

    @discardableResult
    static func move(by value: Int) -> Int {
        let offset = min(max(currentOffset + value, minimumOffset), maximumOffset)
        userDefaults.set(offset, forKey: monthOffsetKey)
        markInteraction()
        return offset
    }

    static func reset() {
        userDefaults.set(0, forKey: monthOffsetKey)
        markInteraction()
    }

    private static func markInteraction() {
        userDefaults.set(Date().timeIntervalSinceReferenceDate, forKey: lastInteractionKey)
    }

    private static var userDefaults: UserDefaults {
        UserDefaults(suiteName: CalendarEventCache.appGroupIdentifier) ?? .standard
    }
}
