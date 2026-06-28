import SwiftUI

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

                if let customDate = day.customSpecialDate {
                    Text(customDate.customLabel)
                        .font(.system(size: compact ? 6 : 8, weight: .bold))
                        .foregroundStyle(.purple)
                        .offset(x: compact ? 5 : 7, y: compact ? -1 : -2)
                } else if let badge = day.holidayBadgeText {
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

        if day.isCustomSpecialDate {
            return .purple
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

        if day.isCustomSpecialDate {
            return .purple
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

        if day.isCustomSpecialDate {
            return Color.purple.opacity(0.14)
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
