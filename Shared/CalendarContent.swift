import Foundation

struct CalendarDay: Identifiable, Hashable {
    let date: Date
    let day: Int
    let lunarText: String
    let markerTexts: [String]
    let isToday: Bool
    let isWeekend: Bool
    let isCurrentMonth: Bool
    let isFestival: Bool
    let holidayBadgeText: String?
    let isRestDay: Bool
    let isWorkdayAdjustment: Bool

    var id: Date { date }
    var markerText: String? {
        markerTexts.isEmpty ? nil : markerTexts.joined(separator: " ")
    }

    var subtitle: String {
        markerText ?? lunarText
    }

    var hasSpecialMarker: Bool {
        isFestival || markerText != nil
    }
}

struct CalendarMonth: Hashable {
    let anchorDate: Date
    let year: Int
    let month: Int
    let title: String
    let weekdaySymbols: [String]
    let days: [CalendarDay]
    let today: CalendarDay?

    var daysWithoutTrailingOutsideWeeks: [CalendarDay] {
        var weeks = stride(from: 0, to: days.count, by: 7).map { start in
            Array(days[start..<min(start + 7, days.count)])
        }

        while let lastWeek = weeks.last, lastWeek.allSatisfy({ !$0.isCurrentMonth }) {
            weeks.removeLast()
        }

        return weeks.flatMap { $0 }
    }

    var hasRemovedTrailingOutsideWeek: Bool {
        daysWithoutTrailingOutsideWeeks.count < days.count
    }

    var hasCompactTrailingOutsideWeek: Bool {
        let displayedDays = daysWithoutTrailingOutsideWeeks
        guard displayedDays.count > 35 else {
            return false
        }

        let trailingWeek = Array(displayedDays.suffix(7))
        let currentMonthDayCount = trailingWeek.filter(\.isCurrentMonth).count
        return currentMonthDayCount > 0
            && currentMonthDayCount <= 2
            && trailingWeek.contains { !$0.isCurrentMonth }
    }

    var compactTrailingCurrentMonthDays: [CalendarDay] {
        guard hasCompactTrailingOutsideWeek else {
            return []
        }

        return Array(daysWithoutTrailingOutsideWeeks.suffix(7).filter(\.isCurrentMonth))
    }

    var daysWithoutCompactTrailingOutsideWeek: [CalendarDay] {
        guard hasCompactTrailingOutsideWeek else {
            return daysWithoutTrailingOutsideWeeks
        }

        return Array(daysWithoutTrailingOutsideWeeks.dropLast(7))
    }
}

struct NextSpecialDay: Hashable {
    let date: Date
    let name: String
    let daysRemaining: Int
    let dateText: String
}

struct TodayInfo: Hashable {
    let dateText: String
    let weekdayText: String
    let lunarText: String
    let displayText: String
}

enum CalendarContent {
    static func month(containing date: Date = Date()) -> CalendarMonth {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 2

        let anchor = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.year, .month], from: anchor)
        let firstOfMonth = calendar.date(from: components) ?? anchor
        let weekdayOffset = (calendar.component(.weekday, from: firstOfMonth) - calendar.firstWeekday + 7) % 7
        let firstGridDate = calendar.date(byAdding: .day, value: -weekdayOffset, to: firstOfMonth) ?? firstOfMonth
        let currentMonth = calendar.component(.month, from: firstOfMonth)
        let currentYear = calendar.component(.year, from: firstOfMonth)
        let todayDate = calendar.startOfDay(for: Date())

        let days = (0..<42).compactMap { offset -> CalendarDay? in
            guard let dayDate = calendar.date(byAdding: .day, value: offset, to: firstGridDate) else {
                return nil
            }

            let dateComponents = calendar.dateComponents([.year, .month, .day, .weekday], from: dayDate)
            guard let day = dateComponents.day, let weekday = dateComponents.weekday else {
                return nil
            }

            let normalizedDate = calendar.startOfDay(for: dayDate)
            let lunar = LunarFormatter.text(for: normalizedDate, calendar: calendar)
            let markers = DayMarker.markers(for: normalizedDate, lunar: lunar, calendar: calendar)
            let holiday = HolidaySchedule.annotation(for: normalizedDate, calendar: calendar)
            let holidayDisplayName = visibleHolidayDisplayName(holiday?.displayName, badgeText: holiday?.badgeText, markers: markers)
            let markerTexts = uniqueMarkerTexts(
                [holidayDisplayName] + markers.map(\.name)
            )
            let isRestDay = holiday?.badgeText == "休"
            let isWorkdayAdjustment = holiday?.badgeText == "班"

            return CalendarDay(
                date: normalizedDate,
                day: day,
                lunarText: lunar.displayText,
                markerTexts: markerTexts,
                isToday: calendar.isDate(normalizedDate, inSameDayAs: todayDate),
                isWeekend: weekday == 1 || weekday == 7,
                isCurrentMonth: dateComponents.month == currentMonth,
                isFestival: holidayDisplayName != nil || markers.contains(where: \.isFestival),
                holidayBadgeText: holiday?.badgeText,
                isRestDay: isRestDay,
                isWorkdayAdjustment: isWorkdayAdjustment
            )
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"

        return CalendarMonth(
            anchorDate: firstOfMonth,
            year: currentYear,
            month: currentMonth,
            title: formatter.string(from: firstOfMonth),
            weekdaySymbols: weekdaySymbols(for: calendar),
            days: days,
            today: days.first(where: \.isToday)
        )
    }

    static func addingMonths(_ value: Int, to date: Date) -> Date {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar.date(byAdding: .month, value: value, to: date) ?? date
    }

    static func todayInfo(for date: Date = Date()) -> TodayInfo {
        let calendar = contentCalendar()
        let startDate = calendar.startOfDay(for: date)
        let lunar = LunarFormatter.text(for: startDate, calendar: calendar)
        let markers = DayMarker.markers(for: startDate, lunar: lunar, calendar: calendar)
        let holiday = HolidaySchedule.annotation(for: startDate, calendar: calendar)
        let holidayDisplayName = visibleHolidayDisplayName(
            holiday?.displayName,
            badgeText: holiday?.badgeText,
            markers: markers
        )
        let displayText = uniqueMarkerTexts([holidayDisplayName] + markers.map(\.name)).first ?? lunar.fullDisplayText

        return TodayInfo(
            dateText: monthDayText(for: startDate, calendar: calendar),
            weekdayText: weekdayText(for: startDate, calendar: calendar),
            lunarText: lunar.fullDisplayText,
            displayText: displayText
        )
    }

    static func nextSpecialDay(after date: Date = Date()) -> NextSpecialDay? {
        nextDay(after: date) { candidateDate, lunar, calendar in
            let markers = DayMarker.markers(for: candidateDate, lunar: lunar, calendar: calendar)
            let holiday = HolidaySchedule.annotation(for: candidateDate, calendar: calendar)
            let holidayDisplayName = visibleHolidayDisplayName(
                holiday?.displayName,
                badgeText: holiday?.badgeText,
                markers: markers
            )
            return uniqueMarkerTexts([holidayDisplayName] + markers.map(\.name)).first
        }
    }

    static func nextFestival(after date: Date = Date()) -> NextSpecialDay? {
        nextDay(after: date) { candidateDate, lunar, calendar in
            let markers = DayMarker.markers(for: candidateDate, lunar: lunar, calendar: calendar)
            let holiday = HolidaySchedule.annotation(for: candidateDate, calendar: calendar)
            let holidayDisplayName = visibleHolidayDisplayName(
                holiday?.displayName,
                badgeText: holiday?.badgeText,
                markers: markers
            )
            return uniqueMarkerTexts([holidayDisplayName] + markers.filter(\.isFestival).map(\.name)).first
        }
    }

    static func nextSolarTerm(after date: Date = Date()) -> NextSpecialDay? {
        nextDay(after: date) { candidateDate, _, calendar in
            let components = calendar.dateComponents([.year, .month, .day], from: candidateDate)
            guard let year = components.year,
                  let month = components.month,
                  let day = components.day else {
                return nil
            }

            return SolarTerm.term(onMonth: month, day: day, year: year)
        }
    }

    private static func nextDay(
        after date: Date,
        named nameProvider: (Date, LunarInfo, Calendar) -> String?
    ) -> NextSpecialDay? {
        let calendar = contentCalendar()
        let startDate = calendar.startOfDay(for: date)

        for offset in 0...370 {
            guard let candidateDate = calendar.date(byAdding: .day, value: offset, to: startDate) else {
                continue
            }

            let lunar = LunarFormatter.text(for: candidateDate, calendar: calendar)
            guard let name = nameProvider(candidateDate, lunar, calendar) else {
                continue
            }

            return NextSpecialDay(
                date: candidateDate,
                name: name,
                daysRemaining: offset,
                dateText: dateText(for: candidateDate, calendar: calendar)
            )
        }

        return nil
    }

    private static func contentCalendar() -> Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }

    private static func weekdaySymbols(for calendar: Calendar) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        let symbols = formatter.shortStandaloneWeekdaySymbols ?? ["日", "一", "二", "三", "四", "五", "六"]
        let startIndex = max(calendar.firstWeekday - 1, 0)
        return (0..<7).map { symbols[($0 + startIndex) % 7].replacingOccurrences(of: "周", with: "") }
    }

    private static func uniqueMarkerTexts(_ texts: [String?]) -> [String] {
        var seen = Set<String>()
        return texts.compactMap { text in
            guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let normalized = normalizedMarkerText(trimmed),
                  !trimmed.isEmpty,
                  !seen.contains(normalized) else {
                return nil
            }

            seen.insert(normalized)
            return trimmed
        }
    }

    private static func normalizedMarkerText(_ text: String) -> String? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return nil
        }

        switch normalized {
        case "端午节":
            return "端午"
        case "中秋节":
            return "中秋"
        case "春节":
            return "春节"
        default:
            return normalized
        }
    }

    private static func visibleHolidayDisplayName(_ displayName: String?, badgeText: String?, markers: [DayMarker]) -> String? {
        guard let displayName,
              let normalizedDisplayName = normalizedMarkerText(displayName) else {
            return nil
        }

        guard badgeText == "休" else {
            return displayName
        }

        let markerNames = Set(markers.compactMap { normalizedMarkerText($0.name) })
        return markerNames.contains(normalizedDisplayName) ? displayName : nil
    }

    private static func dateText(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 E"
        return formatter.string(from: date)
    }

    private static func monthDayText(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    private static func weekdayText(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

struct HolidayAnnotation: Hashable {
    let displayName: String?
    let badgeText: String?
}

enum HolidaySchedule {
    static func annotation(for date: Date, calendar: Calendar) -> HolidayAnnotation? {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return nil
        }

        return merge(
            primary: CalendarEventCache.annotation(for: date, calendar: calendar),
            fallback: restDays[[year, month, day]]
        )
    }

    private static let restDays: [[Int]: HolidayAnnotation] = [
        [2026, 6, 19]: HolidayAnnotation(displayName: "端午节", badgeText: "休"),
        [2026, 6, 20]: HolidayAnnotation(displayName: nil, badgeText: "休"),
        [2026, 6, 21]: HolidayAnnotation(displayName: nil, badgeText: "休")
    ]

    private static func merge(primary: HolidayAnnotation?, fallback: HolidayAnnotation?) -> HolidayAnnotation? {
        guard let primary else {
            return fallback
        }

        guard let fallback else {
            return primary
        }

        return HolidayAnnotation(
            displayName: primary.displayName ?? fallback.displayName,
            badgeText: primary.badgeText ?? fallback.badgeText
        )
    }
}

struct CachedCalendarEvent: Codable, Hashable {
    let dateKey: String
    let title: String
    let badgeText: String?
}

enum CalendarEventCache {
    static let appGroupIdentifier = "group.akmumu.ttcalendar"

    private static let cacheKey = "cachedHolidayEvents"

    static func annotation(for date: Date, calendar: Calendar) -> HolidayAnnotation? {
        let dateKey = dateKey(for: date, calendar: calendar)
        guard let events = load()[dateKey], let event = preferredEvent(from: events) else {
            return nil
        }

        return HolidayAnnotation(displayName: displayTitle(from: events, preferredEvent: event), badgeText: event.badgeText)
    }

    static func save(_ events: [CachedCalendarEvent]) {
        var grouped: [String: [CachedCalendarEvent]] = [:]

        for event in events {
            var dateEvents = grouped[event.dateKey, default: []]
            dateEvents.removeAll { $0.title == event.title && $0.badgeText == event.badgeText }
            dateEvents.append(event)
            grouped[event.dateKey] = dateEvents
        }

        guard let data = try? JSONEncoder().encode(grouped) else {
            return
        }

        userDefaults.set(data, forKey: cacheKey)
    }

    static func dateKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func load() -> [String: [CachedCalendarEvent]] {
        guard let data = userDefaults.data(forKey: cacheKey),
              let grouped = try? JSONDecoder().decode([String: [CachedCalendarEvent]].self, from: data) else {
            return [:]
        }

        return grouped
    }

    private static var userDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    private static func preferredEvent(from events: [CachedCalendarEvent]) -> CachedCalendarEvent? {
        if let rest = events.first(where: { $0.badgeText == "休" }) {
            return rest
        }

        if let workday = events.first(where: { $0.badgeText == "班" }) {
            return workday
        }

        return events.first
    }

    nonisolated private static func displayTitle(for event: CachedCalendarEvent) -> String? {
        let trimmed = sanitizedTitle(event.title)
        if trimmed == event.badgeText {
            return nil
        }

        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated private static func displayTitle(from events: [CachedCalendarEvent], preferredEvent: CachedCalendarEvent) -> String? {
        if let title = displayTitle(for: preferredEvent) {
            return title
        }

        return events.lazy.compactMap(displayTitle(for:)).first
    }

    nonisolated private static func sanitizedTitle(_ title: String) -> String {
        title
            .replacingOccurrences(of: "(休)", with: "")
            .replacingOccurrences(of: "(班)", with: "")
            .replacingOccurrences(of: "（休）", with: "")
            .replacingOccurrences(of: "（班）", with: "")
            .replacingOccurrences(of: "()", with: "")
            .replacingOccurrences(of: "（）", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct LunarInfo: Hashable {
    let month: Int
    let day: Int
    let isLeapMonth: Bool
    let displayText: String

    var fullDisplayText: String {
        if day == 1 {
            return displayText
        }

        return "\(isLeapMonth ? "闰" : "")\(LunarFormatter.monthName(for: month))月\(displayText)"
    }
}

enum LunarFormatter {
    private static let monthNames = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"]
    private static let dayNames = [
        "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
        "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
        "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"
    ]

    static func text(for date: Date, calendar: Calendar) -> LunarInfo {
        var chineseCalendar = Calendar(identifier: .chinese)
        chineseCalendar.timeZone = calendar.timeZone

        let components = chineseCalendar.dateComponents([.month, .day, .isLeapMonth], from: date)
        let month = components.month ?? 1
        let day = components.day ?? 1
        let isLeapMonth = components.isLeapMonth ?? false
        let monthText = "\(isLeapMonth ? "闰" : "")\(monthNames[safe: month - 1] ?? "\(month)")月"
        let dayText = dayNames[safe: day - 1] ?? "\(day)"

        return LunarInfo(
            month: month,
            day: day,
            isLeapMonth: isLeapMonth,
            displayText: day == 1 ? monthText : dayText
        )
    }

    static func monthName(for month: Int) -> String {
        monthNames[safe: month - 1] ?? "\(month)"
    }
}

struct DayMarker: Hashable {
    let name: String
    let isFestival: Bool

    static func markers(for date: Date, lunar: LunarInfo, calendar: Calendar) -> [DayMarker] {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return []
        }

        var markers: [DayMarker] = []

        if let fixed = fixedSolarFestivals[[month, day]] {
            markers.append(fixed)
        }

        if let solarTerm = SolarTerm.term(onMonth: month, day: day, year: year) {
            markers.append(DayMarker(name: solarTerm, isFestival: solarTerm == "清明"))
        }

        if !lunar.isLeapMonth, let lunarFestival = lunarFestivals[[lunar.month, lunar.day]] {
            markers.append(lunarFestival)
        }

        if isLunarNewYearsEve(date: date, calendar: calendar) {
            markers.append(DayMarker(name: "除夕", isFestival: true))
        }

        if let floating = floatingSolarFestival(month: month, day: day, calendar: calendar, date: date) {
            markers.append(floating)
        }

        return markers
    }

    private static let fixedSolarFestivals: [[Int]: DayMarker] = [
        [1, 1]: DayMarker(name: "元旦", isFestival: true),
        [2, 14]: DayMarker(name: "情人节", isFestival: false),
        [3, 8]: DayMarker(name: "妇女节", isFestival: false),
        [3, 12]: DayMarker(name: "植树节", isFestival: false),
        [5, 1]: DayMarker(name: "劳动节", isFestival: true),
        [5, 4]: DayMarker(name: "青年节", isFestival: false),
        [6, 1]: DayMarker(name: "儿童节", isFestival: false),
        [7, 1]: DayMarker(name: "建党节", isFestival: false),
        [8, 1]: DayMarker(name: "建军节", isFestival: false),
        [9, 10]: DayMarker(name: "教师节", isFestival: false),
        [10, 1]: DayMarker(name: "国庆节", isFestival: true),
        [12, 24]: DayMarker(name: "平安夜", isFestival: false),
        [12, 25]: DayMarker(name: "圣诞节", isFestival: false)
    ]

    private static let lunarFestivals: [[Int]: DayMarker] = [
        [1, 1]: DayMarker(name: "春节", isFestival: true),
        [1, 15]: DayMarker(name: "元宵", isFestival: false),
        [5, 5]: DayMarker(name: "端午", isFestival: true),
        [7, 7]: DayMarker(name: "七夕", isFestival: false),
        [8, 15]: DayMarker(name: "中秋", isFestival: true),
        [9, 9]: DayMarker(name: "重阳", isFestival: false),
        [12, 8]: DayMarker(name: "腊八", isFestival: false),
        [12, 23]: DayMarker(name: "小年", isFestival: false)
    ]

    private static func floatingSolarFestival(month: Int, day: Int, calendar: Calendar, date: Date) -> DayMarker? {
        guard month == 5 || month == 6 else {
            return nil
        }

        let weekday = calendar.component(.weekday, from: date)
        let weekdayOrdinal = (day - 1) / 7 + 1

        if month == 5, weekday == 1, weekdayOrdinal == 2 {
            return DayMarker(name: "母亲节", isFestival: false)
        }

        if month == 6, weekday == 1, weekdayOrdinal == 3 {
            return DayMarker(name: "父亲节", isFestival: false)
        }

        return nil
    }

    private static func isLunarNewYearsEve(date: Date, calendar: Calendar) -> Bool {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) else {
            return false
        }

        var chineseCalendar = Calendar(identifier: .chinese)
        chineseCalendar.timeZone = calendar.timeZone
        let components = chineseCalendar.dateComponents([.month, .day, .isLeapMonth], from: tomorrow)
        return components.month == 1 && components.day == 1 && components.isLeapMonth != true
    }
}

enum SolarTerm {
    private struct Definition {
        let month: Int
        let name: String
        let coefficient: Double
    }

    private static let definitions: [Definition] = [
        Definition(month: 1, name: "小寒", coefficient: 5.4055),
        Definition(month: 1, name: "大寒", coefficient: 20.12),
        Definition(month: 2, name: "立春", coefficient: 3.87),
        Definition(month: 2, name: "雨水", coefficient: 18.74),
        Definition(month: 3, name: "惊蛰", coefficient: 5.63),
        Definition(month: 3, name: "春分", coefficient: 20.646),
        Definition(month: 4, name: "清明", coefficient: 4.81),
        Definition(month: 4, name: "谷雨", coefficient: 20.1),
        Definition(month: 5, name: "立夏", coefficient: 5.52),
        Definition(month: 5, name: "小满", coefficient: 21.04),
        Definition(month: 6, name: "芒种", coefficient: 5.678),
        Definition(month: 6, name: "夏至", coefficient: 21.37),
        Definition(month: 7, name: "小暑", coefficient: 7.108),
        Definition(month: 7, name: "大暑", coefficient: 22.83),
        Definition(month: 8, name: "立秋", coefficient: 7.5),
        Definition(month: 8, name: "处暑", coefficient: 23.13),
        Definition(month: 9, name: "白露", coefficient: 7.646),
        Definition(month: 9, name: "秋分", coefficient: 23.042),
        Definition(month: 10, name: "寒露", coefficient: 8.318),
        Definition(month: 10, name: "霜降", coefficient: 23.438),
        Definition(month: 11, name: "立冬", coefficient: 7.438),
        Definition(month: 11, name: "小雪", coefficient: 22.36),
        Definition(month: 12, name: "大雪", coefficient: 7.18),
        Definition(month: 12, name: "冬至", coefficient: 21.94)
    ]

    static func term(onMonth month: Int, day: Int, year: Int) -> String? {
        definitions.first { definition in
            definition.month == month && dayForTerm(definition, year: year) == day
        }?.name
    }

    private static func dayForTerm(_ definition: Definition, year: Int) -> Int {
        let y = year % 100
        return Int(floor(Double(y) * 0.2422 + definition.coefficient)) - Int(floor(Double(y - 1) / 4.0))
    }
}

extension Array {
    fileprivate subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
