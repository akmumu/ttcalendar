import AppIntents
import WidgetKit

struct PreviousMonthIntent: AppIntent {
    static var title: LocalizedStringResource = "上个月"
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult {
        WidgetMonthNavigation.move(by: -1)
        CalendarEventCache.updateRefreshToken()
        WidgetCenter.shared.reloadTimelines(ofKind: CalendarWidgetIdentity.kind)
        return .result()
    }
}

struct NextMonthIntent: AppIntent {
    static var title: LocalizedStringResource = "下个月"
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult {
        WidgetMonthNavigation.move(by: 1)
        CalendarEventCache.updateRefreshToken()
        WidgetCenter.shared.reloadTimelines(ofKind: CalendarWidgetIdentity.kind)
        return .result()
    }
}

struct CurrentMonthIntent: AppIntent {
    static var title: LocalizedStringResource = "回到本月"
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult {
        WidgetMonthNavigation.reset()
        CalendarEventCache.updateRefreshToken()
        WidgetCenter.shared.reloadTimelines(ofKind: CalendarWidgetIdentity.kind)
        return .result()
    }
}
