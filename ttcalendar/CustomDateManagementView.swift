//
//  CustomDateManagementView.swift
//  ttcalendar
//
//  Created by Claude on 2026/6/25.
//

import SwiftUI
import WidgetKit

struct CustomDateManagementView: View {
    private enum DateList: String, CaseIterable {
        case upcoming = "即将到来"
        case archived = "已归档"
    }

    var isCompact = false
    var onDatesChanged: (() -> Void)?
    var onManageAll: (() -> Void)?

    @State private var customDates: [CustomSpecialDate] = []
    @State private var showingAddSheet = false
    @State private var editingDate: CustomSpecialDate?
    @State private var selectedList: DateList = .upcoming

    private var upcomingDates: [CustomSpecialDate] {
        customDates
            .filter { !$0.isArchived() }
            .sorted {
                let left = $0.nextOccurrence() ?? .distantFuture
                let right = $1.nextOccurrence() ?? .distantFuture
                return left == right ? $0.name < $1.name : left < right
            }
    }

    private var archivedDates: [CustomSpecialDate] {
        customDates
            .filter { $0.isArchived() }
            .sorted {
                let left = $0.occurrenceDate() ?? .distantPast
                let right = $1.occurrenceDate() ?? .distantPast
                return left == right ? $0.name < $1.name : left > right
            }
    }

    private var displayedDates: [CustomSpecialDate] {
        selectedList == .upcoming ? upcomingDates : archivedDates
    }

    var body: some View {
        content
        .onAppear {
            loadDates()
        }
        .sheet(isPresented: $showingAddSheet) {
            CustomDateEditView(onSave: { date in
                CustomSpecialDateStore.add(date)
                finishDatesChange()
            })
        }
        .sheet(item: $editingDate) { date in
            CustomDateEditView(editingDate: date, onSave: { updatedDate in
                CustomSpecialDateStore.update(updatedDate)
                finishDatesChange()
            })
        }
    }

    @ViewBuilder
    private var content: some View {
        if isCompact {
            compactBody
        } else {
            regularBody
        }
    }

    private var regularBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("自定义特殊日期")
                    .font(.headline)

                Spacer()

                addButton
                    .buttonStyle(.borderedProminent)
            }

            if customDates.isEmpty {
                emptyState
            } else {
                Picker("日期状态", selection: $selectedList) {
                    Text("即将到来 \(upcomingDates.count)").tag(DateList.upcoming)
                    Text("已归档 \(archivedDates.count)").tag(DateList.archived)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 300)

                dateList
            }
        }
    }

    private var compactBody: some View {
        VStack(spacing: 0) {
            if upcomingDates.isEmpty {
                compactEmptyState
            } else {
                compactDateList
            }

            if !customDates.isEmpty {
                Divider()
                    .padding(.leading, 48)
            }

            Button {
                showingAddSheet = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 26, height: 26)

                    Text("添加日期")
                        .font(.callout)
                        .foregroundStyle(.primary)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .frame(height: 42)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if onManageAll != nil {
                Divider()
                    .padding(.leading, 48)

                Button {
                    onManageAll?()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 26, height: 26)

                        Text("管理全部")
                            .font(.callout)
                            .foregroundStyle(.primary)

                        Spacer()

                        if !archivedDates.isEmpty {
                            Text("\(archivedDates.count) 个已归档")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var addButton: some View {
        Button {
            showingAddSheet = true
        } label: {
            Label("添加", systemImage: "plus.circle.fill")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("还没有自定义日期")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("点击上方\"添加\"按钮创建你的第一个特殊日期")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var compactEmptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)

            Text(customDates.isEmpty ? "还没有自定义日期" : "暂无即将到来的日期")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
    }

    private var dateList: some View {
        VStack(spacing: 8) {
            if displayedDates.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: selectedList == .archived ? "archivebox" : "calendar")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)

                    Text(selectedList == .archived ? "还没有已归档日期" : "暂无即将到来的日期")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                ForEach(displayedDates) { date in
                    CustomDateRow(date: date, isArchived: selectedList == .archived, onEdit: {
                        editingDate = date
                    }, onDelete: {
                        CustomSpecialDateStore.delete(date)
                        finishDatesChange()
                    })
                }
            }
        }
    }

    private var compactDateList: some View {
        VStack(spacing: 0) {
            ForEach(Array(upcomingDates.prefix(4).enumerated()), id: \.element.id) { index, date in
                CompactCustomDateRow(date: date, onEdit: {
                    editingDate = date
                }, onDelete: {
                    CustomSpecialDateStore.delete(date)
                    finishDatesChange()
                })

                if index < min(upcomingDates.count, 4) - 1 {
                    Divider()
                        .padding(.leading, 48)
                }
            }

            if upcomingDates.count > 4 {
                Divider()
                    .padding(.leading, 48)

                Text("还有 \(upcomingDates.count - 4) 个日期")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
            }
        }
    }

    private func loadDates() {
        customDates = CustomSpecialDateStore.load()
    }

    private func reloadWidgets() {
        CalendarEventCache.updateRefreshToken()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func finishDatesChange() {
        loadDates()
        reloadWidgets()
        onDatesChanged?()
    }
}

struct CustomDateRow: View {
    let date: CustomSpecialDate
    let isArchived: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var accentColor: Color {
        isArchived ? .secondary : date.categoryAccentColor
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(isArchived ? 0.08 : 0.15))
                    .frame(width: 40, height: 40)

                Text(date.customLabel)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(date.name)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(isArchived ? .secondary : .primary)

                HStack(spacing: 8) {
                    Text(date.managementDateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(date.type.rawValue)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accentColor.opacity(isArchived ? 0.08 : 0.12), in: Capsule())
                        .foregroundStyle(accentColor)

                    Text(date.category.rawValue)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accentColor.opacity(isArchived ? 0.08 : 0.12), in: Capsule())
                        .foregroundStyle(accentColor)

                    if isArchived {
                        Label("已归档", systemImage: "archivebox.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if date.isYearly {
                        Text("每年")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.blue)
                        .frame(width: 28, height: 28)
                        .background(Color.blue.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red)
                        .frame(width: 28, height: 28)
                        .background(Color.red.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(isArchived ? 0.018 : 0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(accentColor.opacity(isArchived ? 0.12 : 0.2), lineWidth: 1)
                )
        )
    }
}

private struct CompactCustomDateRow: View {
    let date: CustomSpecialDate
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(date.categoryAccentColor.opacity(0.13))
                    .frame(width: 26, height: 26)

                Text(date.customLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(date.categoryAccentColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(date.name)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("\(date.managementDateText) · \(date.category.rawValue) · \(date.type.rawValue)\(date.isYearly ? " · 每年" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 2) {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("编辑")

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .help("删除")
            }
            .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 12)
        .frame(height: 50)
    }
}

private extension CustomSpecialDate {
    var managementDateText: String {
        if !isYearly, let year {
            return "\(year)年\(month)月\(day)日"
        }

        return "\(month)月\(day)日"
    }
}

struct CustomDateEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date
    @State private var type: CustomSpecialDate.DateType
    @State private var category: CustomSpecialDate.DateCategory
    @State private var customLabel: String
    @State private var name: String
    @State private var isYearly: Bool
    @State private var previewDragStartDate: Date?

    private let editingDate: CustomSpecialDate?
    private let onSave: (CustomSpecialDate) -> Void

    init(editingDate: CustomSpecialDate? = nil, onSave: @escaping (CustomSpecialDate) -> Void) {
        self.editingDate = editingDate
        self.onSave = onSave

        if let date = editingDate {
            let calendar = Calendar.current
            let editDate = date.isYearly
                ? date.nextOccurrence(calendar: calendar)
                : date.occurrenceDate(calendar: calendar)
            _selectedDate = State(initialValue: editDate ?? Date())
            _type = State(initialValue: date.type)
            _category = State(initialValue: date.category)
            _customLabel = State(initialValue: date.customLabel)
            _name = State(initialValue: date.name)
            _isYearly = State(initialValue: date.isYearly)
        } else {
            _selectedDate = State(initialValue: Date())
            _type = State(initialValue: .birthday)
            _category = State(initialValue: .life)
            _customLabel = State(initialValue: CustomSpecialDate.DateType.birthday.defaultLabel)
            _name = State(initialValue: "")
            _isYearly = State(initialValue: CustomSpecialDate.DateType.birthday.defaultIsYearly)
        }
    }

    private let nameLimit = 3

    private var month: Int { Calendar.current.component(.month, from: selectedDate) }
    private var day: Int { Calendar.current.component(.day, from: selectedDate) }
    private var year: Int { Calendar.current.component(.year, from: selectedDate) }

    var body: some View {
        VStack(spacing: 0) {
            header

            Form {
                Section("基本信息") {
                    TextField("名称", text: $name, prompt: Text("最多三个字"))
                        .onChange(of: name) { _, newValue in
                            if newValue.count > nameLimit {
                                name = String(newValue.prefix(nameLimit))
                            }
                        }

                    Picker("类型", selection: $type) {
                        ForEach(CustomSpecialDate.DateType.allCases, id: \.self) { dateType in
                            Text(dateType.rawValue).tag(dateType)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: type) { _, newType in
                        customLabel = newType.defaultLabel
                        isYearly = newType.defaultIsYearly
                    }

                    Picker("分类", selection: $category) {
                        ForEach(CustomSpecialDate.DateCategory.allCases, id: \.self) { dateCategory in
                            Text(dateCategory.rawValue).tag(dateCategory)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    DraggableDateCalendar(selectedDate: $selectedDate)

                    Toggle("每年重复", isOn: $isYearly)
                } header: {
                    Text("日期")
                } footer: {
                    Text(isYearly ? "可直接拖动选中日期进行调整；每年重复时只使用月和日，忽略年份。" : "可直接拖动选中日期进行调整；一次性日期到期后自动归档，并保留在对应的历史日期中。")
                }

                Section {
                    TextField("右上角标记", text: $customLabel, prompt: Text("一个字"))
                        .onChange(of: customLabel) { _, newValue in
                            if newValue.count > 1 {
                                customLabel = String(newValue.prefix(1))
                            }
                        }

                    LabeledContent("日历预览") {
                        previewCell
                    }
                } header: {
                    Text("显示效果")
                } footer: {
                    Text("标记会显示在日历格子的右上角，名称显示在格子下方；按住预览向左或向右拖动，也可直接调整日期。")
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack(spacing: 12) {
                Spacer()

                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("保存") {
                    saveDate()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || customLabel.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(width: 480, height: 720)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 24))
                .foregroundStyle(category.categoryAccentColor)

            Text(editingDate == nil ? "添加特殊日期" : "编辑特殊日期")
                .font(.title3.weight(.semibold))

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 4)
    }

    private var previewCell: some View {
        HStack(spacing: 4) {
            WidgetDayCell(day: neighborDay(dayOffset: -1))
                .frame(width: 46)
            WidgetDayCell(day: specialPreviewDay)
                .frame(width: 46)
            WidgetDayCell(day: neighborDay(dayOffset: 1))
                .frame(width: 46)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .gesture(previewDragGesture)
        .help("按住向左或向右拖动以调整日期")
    }

    private func neighborDay(dayOffset: Int) -> CalendarDay {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: dayOffset, to: selectedDate) ?? selectedDate
        return makeCalendarDay(date: date, customSpecialDate: nil)
    }

    private var specialPreviewDay: CalendarDay {
        let preview = CustomSpecialDate(
            year: year,
            month: month,
            day: day,
            type: type,
            category: category,
            customLabel: customLabel.isEmpty ? type.defaultLabel : customLabel,
            name: name.isEmpty ? "名称" : name,
            isYearly: isYearly
        )
        return makeCalendarDay(date: selectedDate, customSpecialDate: preview)
    }

    private func makeCalendarDay(date: Date, customSpecialDate: CustomSpecialDate?) -> CalendarDay {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let lunar = LunarFormatter.text(for: startOfDay, calendar: calendar)
        let weekday = calendar.component(.weekday, from: date)
        return CalendarDay(
            date: startOfDay,
            day: calendar.component(.day, from: date),
            lunarText: lunar.displayText,
            markerTexts: [],
            isToday: false,
            isWeekend: weekday == 1 || weekday == 7,
            isCurrentMonth: true,
            isFestival: false,
            holidayBadgeText: nil,
            isRestDay: false,
            isWorkdayAdjustment: false,
            customSpecialDate: customSpecialDate
        )
    }

    private func saveDate() {
        let date = CustomSpecialDate(
            id: editingDate?.id ?? UUID(),
            year: year,
            month: month,
            day: day,
            type: type,
            category: category,
            customLabel: customLabel.isEmpty ? type.defaultLabel : customLabel,
            name: name,
            isYearly: isYearly
        )

        onSave(date)
        dismiss()
    }

    private var previewDragGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                if previewDragStartDate == nil {
                    previewDragStartDate = Calendar.current.startOfDay(for: selectedDate)
                }

                guard let previewDragStartDate else { return }
                let dayOffset = Int((value.translation.width / 28).rounded())

                if let updatedDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: previewDragStartDate) {
                    selectedDate = Calendar.current.startOfDay(for: updatedDate)
                }
            }
            .onEnded { _ in
                previewDragStartDate = nil
            }
    }
}

/// A calendar that keeps ordinary click-to-select behavior while letting users
/// move the selected date directly: one horizontal cell is one day and one
/// vertical cell is one week.  This avoids making a small date correction a
/// multi-step navigation task in the system date picker.
private struct DraggableDateCalendar: View {
    @Binding var selectedDate: Date

    @State private var displayedMonth: Date
    @State private var dragStartDate: Date?

    private let calendar: Calendar
    private let cellWidth: CGFloat = 43
    private let cellHeight: CGFloat = 38

    init(selectedDate: Binding<Date>) {
        _selectedDate = selectedDate

        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        self.calendar = calendar
        _displayedMonth = State(initialValue: calendar.startOfMonth(for: selectedDate.wrappedValue))
    }

    private var days: [Date] {
        guard let monthRange = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let leadingDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        let totalDays = leadingDays + monthRange.count
        let trailingDays = (7 - totalDays % 7) % 7

        return (0..<(totalDays + trailingDays)).compactMap {
            calendar.date(byAdding: .day, value: $0 - leadingDays, to: firstDay)
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let start = max(0, calendar.firstWeekday - 1)
        return Array(symbols[start...]) + Array(symbols[..<start])
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(displayedMonth, format: .dateTime.year().month(.wide))
                    .font(.headline)

                Spacer()

                Label("拖动日期调整", systemImage: "hand.draw")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: cellWidth, height: 20)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(cellWidth), spacing: 0), count: 7),
                spacing: 0
            ) {
                ForEach(days, id: \.self) { day in
                    dayCell(day)
                }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onChange(of: selectedDate) { _, date in
            displayedMonth = calendar.startOfMonth(for: date)
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isCurrentMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)

        return Button {
            selectedDate = calendar.startOfDay(for: date)
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? Color.white : (isCurrentMonth ? Color.primary : Color.secondary))
                .frame(width: cellWidth, height: cellHeight)
                .background {
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 30, height: 30)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                if dragStartDate == nil {
                    dragStartDate = calendar.startOfDay(for: selectedDate)
                }

                guard let dragStartDate else { return }
                let horizontalDays = Int((value.translation.width / cellWidth).rounded())
                let verticalWeeks = Int((value.translation.height / cellHeight).rounded())
                let offset = horizontalDays + verticalWeeks * 7

                if let updatedDate = calendar.date(byAdding: .day, value: offset, to: dragStartDate) {
                    selectedDate = calendar.startOfDay(for: updatedDate)
                }
            }
            .onEnded { _ in
                dragStartDate = nil
            }
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)).map(startOfDay(for:)) ?? startOfDay(for: date)
    }
}
