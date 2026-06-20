import AppIntents
import WidgetKit

struct PreviousMonthIntent: AppIntent {
    static var title: LocalizedStringResource = "上个月"

    func perform() async throws -> some IntentResult {
        WidgetMonthNavigation.move(by: -1)
        WidgetCenter.shared.reloadTimelines(ofKind: CalendarWidgetIdentity.kind)
        return .result()
    }
}

struct NextMonthIntent: AppIntent {
    static var title: LocalizedStringResource = "下个月"

    func perform() async throws -> some IntentResult {
        WidgetMonthNavigation.move(by: 1)
        WidgetCenter.shared.reloadTimelines(ofKind: CalendarWidgetIdentity.kind)
        return .result()
    }
}

struct CurrentMonthIntent: AppIntent {
    static var title: LocalizedStringResource = "回到本月"

    func perform() async throws -> some IntentResult {
        WidgetMonthNavigation.reset()
        WidgetCenter.shared.reloadTimelines(ofKind: CalendarWidgetIdentity.kind)
        return .result()
    }
}
