import EventKit
import Foundation
import WidgetKit

final class HolidayEventSync {
    static let shared = HolidayEventSync()

    private let eventStore = EKEventStore()

    private init() {}

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    var holidayCalendarNames: [String] {
        guard hasFullCalendarAccess else {
            return []
        }

        return holidayCalendars().map(\.title).sorted()
    }

    func refreshAroundToday(completion: (() -> Void)? = nil) {
        requestAccessIfNeeded { [weak self] granted in
            guard granted else {
                DispatchQueue.main.async {
                    completion?()
                }
                return
            }

            self?.refreshEvents()
            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    func requestAccessAndRefresh(completion: @escaping (Bool) -> Void) {
        requestAccessIfNeeded { [weak self] granted in
            guard granted else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            self?.refreshEvents()
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }

    private func requestAccessIfNeeded(completion: @escaping (Bool) -> Void) {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .fullAccess, .authorized:
            completion(true)
        case .notDetermined:
            requestFullAccess(completion: completion)
        default:
            completion(false)
        }
    }

    private var hasFullCalendarAccess: Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized:
            return true
        default:
            return false
        }
    }

    private func requestFullAccess(completion: @escaping (Bool) -> Void) {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { granted, _ in
                completion(granted)
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, _ in
                completion(granted)
            }
        }
    }

    private func refreshEvents() {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 2

        let now = Date()
        let start = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        let end = calendar.date(byAdding: .month, value: 12, to: now) ?? now
        let eventCalendars = holidayCalendars()

        guard !eventCalendars.isEmpty else {
            return
        }

        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: eventCalendars)
        let events = eventStore.events(matching: predicate).flatMap { event in
            cachedEvents(from: event, calendar: calendar)
        }

        CalendarEventCache.save(events)
        WidgetCenter.shared.reloadTimelines(ofKind: CalendarWidgetIdentity.kind)
    }

    private func holidayCalendars() -> [EKCalendar] {
        eventStore.calendars(for: .event).filter { calendar in
            let lowercasedTitle = calendar.title.lowercased()
            return lowercasedTitle.contains("节假日")
                || lowercasedTitle.contains("假日")
                || lowercasedTitle.contains("holiday")
                || lowercasedTitle.contains("holidays")
        }
    }

    private func cachedEvents(from event: EKEvent, calendar: Calendar) -> [CachedCalendarEvent] {
        guard let startDate = event.startDate else {
            return []
        }

        let endDate = event.endDate ?? startDate
        let title = event.title ?? ""
        let badgeText = badgeText(from: title)

        if !event.isAllDay {
            return [
                CachedCalendarEvent(
                    dateKey: CalendarEventCache.dateKey(for: startDate, calendar: calendar),
                    title: normalizedTitle(title),
                    badgeText: badgeText
                )
            ]
        }

        let normalizedStart = calendar.startOfDay(for: startDate)
        let normalizedEnd = normalizedExclusiveEnd(for: endDate, calendar: calendar)
        let baseDayCount = max(calendar.dateComponents([.day], from: normalizedStart, to: normalizedEnd).day ?? 1, 1)
        let dayCount = baseDayCount + (shouldIncludeVisibleEndDay(badgeText: badgeText, baseDayCount: baseDayCount) ? 1 : 0)
        let normalizedTitle = normalizedTitle(title)

        return (0..<dayCount).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: normalizedStart) else {
                return nil
            }

            return CachedCalendarEvent(
                dateKey: CalendarEventCache.dateKey(for: date, calendar: calendar),
                title: titleForCachedEvent(normalizedTitle, badgeText: badgeText, offset: offset),
                badgeText: badgeText
            )
        }
    }

    private func titleForCachedEvent(_ title: String, badgeText: String?, offset: Int) -> String {
        if badgeText != nil && offset > 0 {
            return ""
        }

        return title
    }

    private func normalizedExclusiveEnd(for endDate: Date, calendar: Calendar) -> Date {
        let startOfEndDate = calendar.startOfDay(for: endDate)
        if calendar.isDate(endDate, inSameDayAs: startOfEndDate) {
            return startOfEndDate
        }

        return calendar.date(byAdding: .day, value: 1, to: startOfEndDate) ?? startOfEndDate
    }

    private func shouldIncludeVisibleEndDay(badgeText: String?, baseDayCount: Int) -> Bool {
        badgeText != nil && baseDayCount > 1
    }

    private func badgeText(from title: String) -> String? {
        if title.contains("休") {
            return "休"
        }

        if title.contains("班") {
            return "班"
        }

        return nil
    }

    private func normalizedTitle(_ title: String) -> String {
        title
            .replacingOccurrences(of: "(休)", with: "")
            .replacingOccurrences(of: "(班)", with: "")
            .replacingOccurrences(of: "（休）", with: "")
            .replacingOccurrences(of: "（班）", with: "")
            .replacingOccurrences(of: "休", with: "")
            .replacingOccurrences(of: "班", with: "")
            .replacingOccurrences(of: "()", with: "")
            .replacingOccurrences(of: "（）", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
