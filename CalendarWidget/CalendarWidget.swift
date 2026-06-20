//
//  CalendarWidget.swift
//  CalendarWidget
//
//  Created by zhangqinglong on 2026/6/15.
//

import WidgetKit
import SwiftUI
import AppIntents

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        makeEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(makeEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let now = Date()
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent

        let nextRefresh = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 2),
            matchingPolicy: .nextTime
        ) ?? calendar.date(byAdding: .hour, value: 1, to: now) ?? now

        let entry = makeEntry(date: now)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func makeEntry(date: Date) -> SimpleEntry {
        SimpleEntry(
            date: date,
            month: CalendarContent.month(containing: WidgetMonthNavigation.currentMonthAnchor),
            nextMonth: CalendarContent.month(containing: CalendarContent.addingMonths(1, to: WidgetMonthNavigation.currentMonthAnchor)),
            todayInfo: CalendarContent.todayInfo(for: date),
            nextSpecialDay: CalendarContent.nextSpecialDay(after: date),
            nextFestival: CalendarContent.nextFestival(after: date),
            nextSolarTerm: CalendarContent.nextSolarTerm(after: date),
            monthOffset: WidgetMonthNavigation.currentOffset
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let month: CalendarMonth
    let nextMonth: CalendarMonth
    let todayInfo: TodayInfo
    let nextSpecialDay: NextSpecialDay?
    let nextFestival: NextSpecialDay?
    let nextSolarTerm: NextSpecialDay?
    let monthOffset: Int
}

struct CalendarWidgetEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily

    var entry: Provider.Entry

    var body: some View {
        Group {
            if widgetFamily == .systemExtraLarge {
                extraLargeBody
            } else {
                largeBody
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
    }

    private var largeBody: some View {
        let embedsCountdown = entry.month.hasCompactTrailingOutsideWeek && entry.nextSpecialDay != nil

        return VStack(alignment: .leading, spacing: 8) {
            header(title: entry.month.title)
            WidgetMonthGrid(
                days: entry.month.daysWithoutTrailingOutsideWeeks,
                weekdaySymbols: entry.month.weekdaySymbols,
                embeddedSpecialDay: embedsCountdown ? entry.nextSpecialDay : nil
            )

            if let nextSpecialDay = entry.nextSpecialDay, !embedsCountdown {
                NextSpecialDayBar(specialDay: nextSpecialDay)
            }
        }
    }

    private var mediumBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            header(title: entry.month.title, compact: true)
            WidgetMonthGrid(month: entry.month, compact: true)
        }
    }

    private var extraLargeBody: some View {
        let monthDays = entry.month.daysWithoutCompactTrailingOutsideWeek
        let nextMonthDays = entry.nextMonth.daysWithoutCompactTrailingOutsideWeek
        let showsBottomRow = monthDays.count <= 35 && nextMonthDays.count <= 35

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 14) {
                monthTitle(entry.month.title, style: .large)

                HStack(alignment: .center) {
                    monthTitle(entry.nextMonth.title, style: .large)
                    Spacer()
                    actionButtons()
                }
                .frame(maxWidth: .infinity)
            }

            HStack(alignment: .top, spacing: 14) {
                WidgetMonthPanel(month: entry.month, days: monthDays, titleStyle: .hidden)
                WidgetMonthPanel(month: entry.nextMonth, days: nextMonthDays, titleStyle: .hidden)
            }

            if showsBottomRow {
                ExtraLargeBottomRow(
                    leftDays: entry.month.compactTrailingCurrentMonthDays,
                    rightDays: entry.nextMonth.compactTrailingCurrentMonthDays,
                    todayInfo: entry.todayInfo,
                    festival: entry.nextFestival,
                    solarTerm: entry.nextSolarTerm
                )
            }
        }
    }

    private func header(title: String, compact: Bool = false) -> some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: compact ? 15 : 20, weight: .semibold, design: .rounded))

            Spacer()

            actionButtons(spacing: compact ? 4 : 6)
        }
    }

    private func monthTitle(_ title: String, style: WidgetMonthPanel.TitleStyle) -> some View {
        Text(title)
            .font(.system(size: style == .large ? 20 : 13, weight: .semibold, design: .rounded))
            .foregroundStyle(style == .large ? .primary : .secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionButtons(spacing: CGFloat = 6) -> some View {
        HStack(spacing: spacing) {
            widgetButton(systemName: "chevron.left", intent: PreviousMonthIntent(), help: "上个月")
            widgetButton(systemName: "circle.grid.2x1.left.filled", intent: CurrentMonthIntent(), help: "回到本月")
            widgetButton(systemName: "chevron.right", intent: NextMonthIntent(), help: "下个月")
        }
    }

    private func widgetButton<I: AppIntent>(systemName: String, intent: I, help: String) -> some View {
        Button(intent: intent) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.85))
                        .overlay(
                            Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }

}

struct WidgetMonthPanel: View {
    enum TitleStyle {
        case hidden
        case small
        case large
    }

    let month: CalendarMonth
    var days: [CalendarDay]? = nil
    var titleStyle: TitleStyle = .small

    var body: some View {
        VStack(alignment: .leading, spacing: titleStyle == .hidden ? 0 : 8) {
            if titleStyle != .hidden {
                Text(month.title)
                    .font(.system(size: titleStyle == .large ? 20 : 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(titleStyle == .large ? .primary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            WidgetMonthGrid(days: days ?? month.daysWithoutTrailingOutsideWeeks, weekdaySymbols: month.weekdaySymbols)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WidgetMonthGrid: View {
    init(month: CalendarMonth, compact: Bool = false) {
        self.weekdaySymbols = month.weekdaySymbols
        self.days = month.days
        self.compact = compact
        self.embeddedSpecialDay = nil
    }

    init(days: [CalendarDay], weekdaySymbols: [String], compact: Bool = false, embeddedSpecialDay: NextSpecialDay? = nil) {
        self.weekdaySymbols = weekdaySymbols
        self.days = days
        self.compact = compact
        self.embeddedSpecialDay = embeddedSpecialDay
    }

    private let days: [CalendarDay]
    private let weekdaySymbols: [String]
    private let compact: Bool
    private let embeddedSpecialDay: NextSpecialDay?
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)

    var body: some View {
        VStack(spacing: compact ? 3 : 5) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { weekday in
                    Text(weekday)
                        .font(.system(size: compact ? 8 : 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            if let embeddedSpecialDay {
                embeddedGrid(specialDay: embeddedSpecialDay)
            } else {
                LazyVGrid(columns: columns, spacing: compact ? 2 : 4) {
                    ForEach(days) { day in
                        WidgetDayCell(day: day, compact: compact)
                    }
                }
            }
        }
    }

    private func embeddedGrid(specialDay: NextSpecialDay) -> some View {
        let fullWeeks = Array(days.dropLast(7))
        let trailingCurrentMonthDays = Array(days.suffix(7).filter(\.isCurrentMonth))
        let countdownSpan = max(7 - trailingCurrentMonthDays.count, 1)

        return VStack(spacing: compact ? 2 : 4) {
            LazyVGrid(columns: columns, spacing: compact ? 2 : 4) {
                ForEach(fullWeeks) { day in
                    WidgetDayCell(day: day, compact: compact)
                }
            }

            GeometryReader { proxy in
                let columnSpacing: CGFloat = 3
                let columnWidth = (proxy.size.width - columnSpacing * 6) / 7
                let countdownWidth = columnWidth * CGFloat(countdownSpan) + columnSpacing * CGFloat(countdownSpan - 1)

                HStack(spacing: columnSpacing) {
                    ForEach(trailingCurrentMonthDays) { day in
                        WidgetDayCell(day: day, compact: compact)
                            .frame(width: columnWidth)
                    }

                    EmbeddedSpecialDayBar(specialDay: specialDay)
                        .frame(width: countdownWidth)
                }
            }
            .frame(height: compact ? 24 : 40)
        }
    }
}

struct NextSpecialDayBar: View {
    let specialDay: NextSpecialDay

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.red)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.red.opacity(0.11)))

            countdownText

            Spacer(minLength: 6)

            Text(specialDay.dateText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.red.opacity(0.16), lineWidth: 1)
                )
        )
    }

    private var countdownText: some View {
        HStack(alignment: .center, spacing: 4) {
            Text("距\(specialDay.name)还有")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            Text("\(specialDay.daysRemaining)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.red)

            Text("天")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .frame(height: 28, alignment: .center)
    }
}

struct EmbeddedSpecialDayBar: View {
    let specialDay: NextSpecialDay

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.red)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.red.opacity(0.11)))

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("距\(specialDay.name)还有")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("\(specialDay.daysRemaining)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.red)

                Text("天")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.72)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.red.opacity(0.16), lineWidth: 1)
                )
        )
    }
}

struct ExtraLargeBottomRow: View {
    let leftDays: [CalendarDay]
    let rightDays: [CalendarDay]
    let todayInfo: TodayInfo
    let festival: NextSpecialDay?
    let solarTerm: NextSpecialDay?

    var body: some View {
        GeometryReader { proxy in
            let panelSpacing: CGFloat = 14
            let columnSpacing: CGFloat = 3
            let panelWidth = (proxy.size.width - panelSpacing) / 2
            let columnWidth = (panelWidth - columnSpacing * 6) / 7
            let leftWidth = overflowWidth(for: leftDays.count, columnWidth: columnWidth, spacing: columnSpacing)
            let rightWidth = overflowWidth(for: rightDays.count, columnWidth: columnWidth, spacing: columnSpacing)
            let leadingInset = leftWidth > 0 ? leftWidth + panelSpacing : 0
            let trailingInset = rightWidth > 0 ? rightWidth + panelSpacing : 0

            ZStack {
                ExtraLargeInfoBar(
                    todayInfo: todayInfo,
                    festival: festival,
                    solarTerm: solarTerm
                )
                .padding(.leading, leadingInset)
                .padding(.trailing, trailingInset)

                HStack {
                    HStack(spacing: columnSpacing) {
                        ForEach(leftDays) { day in
                            WidgetDayCell(day: day)
                                .frame(width: columnWidth)
                        }
                    }
                    .frame(width: leftWidth, height: 40, alignment: .leading)

                    Spacer(minLength: 0)

                    HStack(spacing: columnSpacing) {
                        ForEach(rightDays) { day in
                            WidgetDayCell(day: day)
                                .frame(width: columnWidth)
                        }
                    }
                    .frame(width: rightWidth, height: 40, alignment: .trailing)
                }
            }
            .frame(height: 40)
        }
        .frame(height: 40)
    }

    private func overflowWidth(for count: Int, columnWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        guard count > 0 else {
            return 0
        }

        return columnWidth * CGFloat(count) + spacing * CGFloat(count - 1)
    }
}

struct ExtraLargeInfoBar: View {
    let todayInfo: TodayInfo
    let festival: NextSpecialDay?
    let solarTerm: NextSpecialDay?

    var body: some View {
        HStack(spacing: 8) {
            ExtraLargeInfoItem(
                systemName: "calendar",
                title: "今天",
                value: todayInfo.displayText,
                detail: "\(todayInfo.dateText) \(todayInfo.weekdayText)",
                accent: .accentColor
            )

            if let festival {
                ExtraLargeInfoItem(
                    systemName: "timer",
                    title: festival.name,
                    value: "还有 \(festival.daysRemaining) 天",
                    detail: festival.dateText,
                    accent: .red
                )
            }

            if let solarTerm {
                ExtraLargeInfoItem(
                    systemName: "leaf",
                    title: solarTerm.name,
                    value: "还有 \(solarTerm.daysRemaining) 天",
                    detail: solarTerm.dateText,
                    accent: .green
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 36)
    }
}

struct ExtraLargeInfoItem: View {
    let systemName: String
    let title: String
    let value: String
    let detail: String?
    let accent: Color

    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 24, height: 24)
                .background(Circle().fill(accent.opacity(0.11)))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(value)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                        .lineLimit(1)

                    if let detail {
                        Text(detail)
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .minimumScaleFactor(0.82)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(accent.opacity(0.14), lineWidth: 1)
                )
        )
    }
}

struct WidgetDayCell: View {
    let day: CalendarDay
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 1 : 2) {
            ZStack(alignment: .topTrailing) {
                Text("\(day.day)")
                    .font(.system(size: compact ? 10 : 13, weight: day.isToday ? .bold : .semibold))
                    .foregroundStyle(dayForeground)
                    .frame(width: compact ? 16 : 22, height: compact ? 16 : 22)
                    .background {
                        if day.isToday {
                            Circle()
                                .fill(Color.accentColor)
                        }
                    }

                if let badge = day.holidayBadgeText {
                    Text(badge)
                        .font(.system(size: compact ? 6 : 8, weight: .bold))
                        .foregroundStyle(badgeForeground)
                        .offset(x: compact ? 5 : 7, y: compact ? -1 : -2)
                }
            }

            Text(day.subtitle)
                .font(.system(size: compact ? 6.5 : 8.5, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(subtitleForeground)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, compact ? 1 : 3)
        .frame(maxWidth: .infinity)
        .frame(height: compact ? 24 : 40)
        .background(cellBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var dayForeground: Color {
        if day.isToday {
            return .white
        }

        if !day.isCurrentMonth {
            return .secondary
        }

        if day.isWorkdayAdjustment {
            return workdayAdjustmentColor
        }

        if day.isRestDay || day.hasSpecialMarker {
            return .red
        }

        if day.isWeekend && !day.isWorkdayAdjustment {
            return .secondary
        }

        return .primary
    }

    private var subtitleForeground: Color {
        if !day.isCurrentMonth {
            return .secondary.opacity(0.55)
        }

        if day.isWorkdayAdjustment {
            return workdayAdjustmentColor
        }

        if day.isRestDay || day.hasSpecialMarker {
            return .red
        }

        return .secondary
    }

    private var badgeForeground: Color {
        day.isWorkdayAdjustment ? workdayAdjustmentColor : .green
    }

    private var workdayAdjustmentColor: Color {
        .orange
    }

    private var cellBackground: some ShapeStyle {
        if day.isToday {
            return Color.accentColor.opacity(0.12)
        }

        if day.isWorkdayAdjustment {
            return Color.orange.opacity(0.14)
        }

        if day.isRestDay {
            return Color.pink.opacity(0.14)
        }

        return Color.primary.opacity(day.isCurrentMonth ? 0.035 : 0.012)
    }
}

struct CalendarWidget: Widget {
    let kind: String = CalendarWidgetIdentity.kind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CalendarWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(nsColor: .windowBackgroundColor)
                }
        }
        .configurationDisplayName("抬头日历")
        .description("显示农历、节日和节气。")
        .supportedFamilies([.systemLarge, .systemExtraLarge])
    }
}
