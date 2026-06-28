//
//  CustomDateManagementView.swift
//  ttcalendar
//
//  Created by Claude on 2026/6/25.
//

import SwiftUI
import WidgetKit

struct CustomDateManagementView: View {
    @State private var customDates: [CustomSpecialDate] = []
    @State private var showingAddSheet = false
    @State private var editingDate: CustomSpecialDate?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("自定义特殊日期")
                    .font(.headline)

                Spacer()

                Button {
                    showingAddSheet = true
                } label: {
                    Label("添加", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }

            if customDates.isEmpty {
                emptyState
            } else {
                dateList
            }
        }
        .onAppear {
            loadDates()
        }
        .sheet(isPresented: $showingAddSheet) {
            CustomDateEditView(onSave: { date in
                CustomSpecialDateStore.add(date)
                loadDates()
                reloadWidgets()
            })
        }
        .sheet(item: $editingDate) { date in
            CustomDateEditView(editingDate: date, onSave: { updatedDate in
                CustomSpecialDateStore.update(updatedDate)
                loadDates()
                reloadWidgets()
            })
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

    private var dateList: some View {
        VStack(spacing: 8) {
            ForEach(customDates) { date in
                CustomDateRow(date: date, onEdit: {
                    editingDate = date
                }, onDelete: {
                    CustomSpecialDateStore.delete(date)
                    loadDates()
                    reloadWidgets()
                })
            }
        }
    }

    private func loadDates() {
        customDates = CustomSpecialDateStore.load().sorted { $0.month < $1.month || ($0.month == $1.month && $0.day < $1.day) }
    }

    private func reloadWidgets() {
        CalendarEventCache.updateRefreshToken()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct CustomDateRow: View {
    let date: CustomSpecialDate
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 40, height: 40)

                Text(date.customLabel)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.purple)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(date.name)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Text("\(date.month)月\(date.day)日")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(date.type.rawValue)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.12), in: Capsule())
                        .foregroundStyle(.purple)

                    if date.isYearly {
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
                .fill(Color.primary.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct CustomDateEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date
    @State private var type: CustomSpecialDate.DateType
    @State private var customLabel: String
    @State private var name: String
    @State private var isYearly: Bool

    private let editingDate: CustomSpecialDate?
    private let onSave: (CustomSpecialDate) -> Void

    init(editingDate: CustomSpecialDate? = nil, onSave: @escaping (CustomSpecialDate) -> Void) {
        self.editingDate = editingDate
        self.onSave = onSave

        if let date = editingDate {
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year], from: Date())
            components.month = date.month
            components.day = date.day
            _selectedDate = State(initialValue: calendar.date(from: components) ?? Date())
            _type = State(initialValue: date.type)
            _customLabel = State(initialValue: date.customLabel)
            _name = State(initialValue: date.name)
            _isYearly = State(initialValue: date.isYearly)
        } else {
            _selectedDate = State(initialValue: Date())
            _type = State(initialValue: .birthday)
            _customLabel = State(initialValue: CustomSpecialDate.DateType.birthday.defaultLabel)
            _name = State(initialValue: "")
            _isYearly = State(initialValue: CustomSpecialDate.DateType.birthday.defaultIsYearly)
        }
    }

    private let nameLimit = 3

    private var month: Int { Calendar.current.component(.month, from: selectedDate) }
    private var day: Int { Calendar.current.component(.day, from: selectedDate) }

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
                }

                Section {
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)

                    Toggle("每年重复", isOn: $isYearly)
                } header: {
                    Text("日期")
                } footer: {
                    Text(isYearly ? "每年重复：只使用月和日，忽略年份。" : "在日历上选择具体日期。")
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
                    Text("标记会显示在日历格子的右上角，名称显示在格子下方。")
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
                .foregroundStyle(.purple)

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
    }

    private func neighborDay(dayOffset: Int) -> CalendarDay {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: dayOffset, to: selectedDate) ?? selectedDate
        return makeCalendarDay(date: date, customSpecialDate: nil)
    }

    private var specialPreviewDay: CalendarDay {
        let preview = CustomSpecialDate(
            month: month,
            day: day,
            type: type,
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
            month: month,
            day: day,
            type: type,
            customLabel: customLabel.isEmpty ? type.defaultLabel : customLabel,
            name: name,
            isYearly: isYearly
        )

        onSave(date)
        dismiss()
    }
}
