//
//  ContentView.swift
//  ttcalendar
//
//  Created by zhangqinglong on 2026/6/15.
//

import EventKit
import AppKit
import SwiftUI
import WidgetKit

struct ContentView: View {
    private enum DetailMode {
        case preview
        case widgetSetup
        case customDates
        case settings
    }

    @EnvironmentObject private var updaterViewModel: UpdaterViewModel
    @State private var authorizationStatus = HolidayEventSync.shared.authorizationStatus
    @State private var holidayCalendarNames = HolidayEventSync.shared.holidayCalendarNames
    @State private var isRefreshingCalendar = false
    @State private var calendarMessage: String?
    @State private var holidayCalendarMessage: String?
    @State private var widgetRefreshMessage: String?
    @State private var previewRefreshToken = CalendarEventCache.refreshToken
    @State private var previewDate = Date()
    @State private var previewMonthOffset = 0
    @State private var lastRefreshDate = Date()
    @State private var detailMode: DetailMode = .preview

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Rectangle()
                .fill(DashboardPalette.divider)
                .frame(width: 1)

            previewPane
        }
        .frame(minWidth: 1080, minHeight: 640)
        .background(DashboardPalette.appBackground)
        .onAppear {
            refreshDashboardState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshDashboardState()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            appHeader

            Rectangle()
                .fill(DashboardPalette.divider)
                .frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    statusSection
                    DashboardDivider()
                    customDateSection
                    DashboardDivider()
                    toolsSection
                }
                .padding(.vertical, 10)
            }
        }
        .frame(width: 340)
        .background(DashboardPalette.sidebarBackground)
    }

    private var appHeader: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("抬头日历")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DashboardPalette.primaryText)

                Text("最后刷新：\(lastRefreshText)")
                    .font(.caption)
                    .foregroundStyle(DashboardPalette.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text("v\(appVersion)")
                .font(.caption.weight(.medium))
                .foregroundStyle(DashboardPalette.secondaryText)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var statusSection: some View {
        DashboardSection("使用") {
            WidgetSetupGuide {
                detailMode = .widgetSetup
            }

            DashboardListDivider()

            StatusListRow(
                systemName: "calendar.badge.checkmark",
                title: "日历权限",
                value: calendarStatusTitle,
                statusSystemName: calendarStatusIcon,
                statusTint: calendarStepAccent
            )

            DashboardListDivider()

            StatusListRow(
                systemName: "calendar.day.timeline.left",
                title: "节假日日历",
                value: holidayStatusTitle,
                statusSystemName: holidayStatusIcon,
                statusTint: holidayStepAccent
            )

            if let statusMessage {
                DashboardListDivider()

                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(statusMessageColor)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
    }

    private var customDateSection: some View {
        DashboardSection("自定义日期") {
            CustomDateManagementView(
                isCompact: true,
                onDatesChanged: refreshPreview,
                onManageAll: {
                    detailMode = .customDates
                }
            )
        }
    }

    private var toolsSection: some View {
        DashboardSection("设置") {
            ActionListRow(
                systemName: "gearshape",
                title: "桌面小组件设置",
                subtitle: "权限、节假日与刷新"
            ) {
                detailMode = .settings
            }

            DashboardListDivider()

            ActionListRow(
                systemName: "arrow.down.circle",
                title: "检查更新",
                subtitle: "检查最新版本",
                isDisabled: !updaterViewModel.canCheckForUpdates
            ) {
                updaterViewModel.checkForUpdates()
            }
        }
    }

    private var previewPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(detailTitle)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(DashboardPalette.primaryText)

                    Text(detailSubtitle)
                        .font(.callout)
                        .foregroundStyle(DashboardPalette.secondaryText)
                }

                Spacer()

                HStack(spacing: 8) {
                    if detailMode != .preview {
                        DashboardToolbarButton(systemName: "calendar", title: "返回") {
                            detailMode = .preview
                        }
                        .help("返回实时预览")
                    }

                    DashboardToolbarButton(systemName: "arrow.clockwise", title: "刷新") {
                        forceReloadWidgets()
                    }
                    .help("刷新桌面小组件")

                    DashboardToolbarButton(systemName: "questionmark.circle", title: "帮助") {
                        detailMode = .widgetSetup
                    }
                    .help("查看添加桌面小组件说明")

                    DashboardToolbarButton(systemName: "link", title: "GitHub") {
                        openGitHubRepository()
                    }
                    .help("打开 GitHub 仓库")
                }
            }

            detailContent

            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DashboardPalette.previewBackground)
    }

    private var detailTitle: String {
        switch detailMode {
        case .preview:
            return "实时预览"
        case .widgetSetup:
            return "添加桌面小组件"
        case .customDates:
            return "管理自定义日期"
        case .settings:
            return "桌面小组件设置"
        }
    }

    private var detailSubtitle: String {
        switch detailMode {
        case .preview:
            return previewSubtitle
        case .widgetSetup:
            return "按步骤把抬头日历添加到桌面"
        case .customDates:
            return "完整管理会同步刷新桌面小组件"
        case .settings:
            return "管理权限、节假日数据和刷新"
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch detailMode {
        case .preview:
            DashboardWidgetPreview(
                monthAnchorDate: previewMonthAnchorDate,
                todayDate: previewDate,
                monthOffset: previewMonthOffset,
                onPreviousMonth: {
                    movePreviewMonth(by: -1)
                },
                onCurrentMonth: {
                    resetPreviewMonth()
                },
                onNextMonth: {
                    movePreviewMonth(by: 1)
                }
            )
                .id(previewRefreshToken)
                .frame(maxWidth: 820, alignment: .leading)
        case .widgetSetup:
            WidgetSetupDetailView()
                .frame(maxWidth: 820, alignment: .leading)
        case .customDates:
            CustomDateManagementView(
                onDatesChanged: {
                    refreshPreview()
                }
            )
            .padding(18)
            .frame(maxWidth: 820, alignment: .leading)
            .dashboardMaterialCard(radius: 10)
        case .settings:
            SettingsDetailView(
                accessIcon: accessButtonIcon,
                accessTitle: accessButtonTitle,
                accessSubtitle: calendarStepDetail,
                isAccessDisabled: isRefreshingCalendar || isAccessActionDisabled,
                holidaySubtitle: holidayStepDetail,
                isHolidayDisabled: isRefreshingCalendar || !hasCalendarAccess,
                isCalendarDisabled: !hasCalendarAccess,
                widgetSubtitle: widgetRefreshMessage ?? "让桌面小组件重新读取数据",
                statusMessage: statusMessage,
                statusMessageColor: statusMessageColor,
                onAccess: performAccessAction,
                onRefreshHoliday: refreshHolidayCalendarData,
                onOpenCalendar: openCalendarApp,
                onRefreshWidgets: forceReloadWidgets
            )
            .frame(maxWidth: 820, alignment: .leading)
        }
    }

    private var previewSubtitle: String {
        if let widgetRefreshMessage {
            return widgetRefreshMessage
        }

        return "基于当前日期、自定义日期和节假日缓存生成"
    }

    private var previewMonthAnchorDate: Date {
        CalendarContent.addingMonths(previewMonthOffset, to: previewDate)
    }

    private var lastRefreshText: String {
        let elapsed = Date().timeIntervalSince(lastRefreshDate)

        if elapsed < 60 {
            return "刚刚"
        }

        if elapsed < 3600 {
            return "\(max(Int(elapsed / 60), 1)) 分钟前"
        }

        return lastRefreshDate.formatted(date: .omitted, time: .shortened)
    }

    private var statusMessage: String? {
        calendarMessage ?? holidayCalendarMessage
    }

    private var statusMessageColor: AnyShapeStyle {
        if calendarMessage != nil {
            return AnyShapeStyle(messageColor)
        }

        return holidayStepDetailColor
    }

    private var calendarStatusTitle: String {
        switch authorizationStatus {
        case .fullAccess, .authorized:
            return "已开启"
        case .notDetermined:
            return "待授权"
        case .denied:
            return "未开启"
        case .restricted:
            return "受限制"
        case .writeOnly:
            return "仅写入"
        @unknown default:
            return "未知"
        }
    }

    private var calendarStatusIcon: String {
        switch authorizationStatus {
        case .fullAccess, .authorized:
            return "checkmark.circle.fill"
        case .denied, .restricted:
            return "xmark.circle.fill"
        case .writeOnly:
            return "exclamationmark.circle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }

    private var holidayStatusTitle: String {
        guard hasCalendarAccess else {
            return "待授权"
        }

        return holidayCalendarNames.isEmpty ? "未检测到" : "已检测到"
    }

    private var holidayStatusIcon: String {
        guard hasCalendarAccess else {
            return "questionmark.circle.fill"
        }

        return holidayCalendarNames.isEmpty ? "exclamationmark.circle.fill" : "checkmark.circle.fill"
    }

    private var calendarStepDetail: String {
        switch authorizationStatus {
        case .fullAccess, .authorized:
            return "已授权，可读取本机节假日。"
        case .notDetermined:
            return "需授权读取日历节假日。"
        case .denied:
            return "权限已关闭，去设置里开启。"
        case .restricted:
            return "系统限制了日历访问。"
        case .writeOnly:
            return "仅写入权限，需完整访问。"
        @unknown default:
            return "无法确认权限状态。"
        }
    }

    private var calendarStepAccent: Color {
        switch authorizationStatus {
        case .fullAccess, .authorized:
            return DashboardPalette.success
        case .denied, .restricted:
            return DashboardPalette.danger
        case .writeOnly:
            return DashboardPalette.warning
        default:
            return DashboardPalette.accent
        }
    }

    private var holidayStepDetail: String {
        guard hasCalendarAccess else {
            return "先开启日历权限再检测。"
        }

        if holidayCalendarNames.isEmpty {
            return "未检测到，去日历勾选“节假日”。"
        }

        return "已读取：\(holidayCalendarNames.joined(separator: "、"))"
    }

    private var holidayStepDetailColor: AnyShapeStyle {
        if holidayCalendarMessage != nil {
            return AnyShapeStyle(holidayCalendarNames.isEmpty ? DashboardPalette.warning : DashboardPalette.success)
        }
        guard hasCalendarAccess else { return AnyShapeStyle(DashboardPalette.secondaryText) }
        return AnyShapeStyle(holidayCalendarNames.isEmpty ? DashboardPalette.warning : DashboardPalette.success)
    }

    private var holidayStepAccent: Color {
        guard hasCalendarAccess else { return DashboardPalette.secondaryText }
        return holidayCalendarNames.isEmpty ? DashboardPalette.warning : DashboardPalette.success
    }

    private var accessButtonTitle: String {
        switch authorizationStatus {
        case .fullAccess, .authorized:
            return "重新读取日历"
        case .denied:
            return "打开设置授权"
        case .restricted:
            return "系统限制访问"
        default:
            return "申请日历权限"
        }
    }

    private var accessButtonIcon: String {
        switch authorizationStatus {
        case .fullAccess, .authorized:
            return "arrow.clockwise"
        case .denied:
            return "gearshape"
        case .restricted:
            return "lock.slash"
        default:
            return "lock.open"
        }
    }

    private var messageColor: Color {
        switch authorizationStatus {
        case .fullAccess, .authorized:
            return DashboardPalette.success
        case .denied, .restricted:
            return DashboardPalette.danger
        default:
            return DashboardPalette.secondaryText
        }
    }

    private var hasCalendarAccess: Bool {
        switch authorizationStatus {
        case .fullAccess, .authorized:
            return true
        default:
            return false
        }
    }

    private var isAccessActionDisabled: Bool {
        authorizationStatus == .restricted
    }

    private func refreshDashboardState() {
        refreshAuthorizationStatus()
        refreshHolidayCalendarNames()
        refreshPreview()
    }

    private func refreshAuthorizationStatus() {
        authorizationStatus = HolidayEventSync.shared.authorizationStatus
    }

    private func refreshHolidayCalendarNames() {
        holidayCalendarNames = HolidayEventSync.shared.holidayCalendarNames
    }

    private func refreshPreview() {
        previewDate = Date()
        previewRefreshToken = Date().timeIntervalSinceReferenceDate
        lastRefreshDate = Date()
    }

    private func movePreviewMonth(by value: Int) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            previewMonthOffset += value
        }
    }

    private func resetPreviewMonth() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            previewMonthOffset = 0
        }
    }

    private func performAccessAction() {
        switch authorizationStatus {
        case .denied:
            openCalendarPrivacySettings()
        default:
            requestCalendarAccess()
        }
    }

    private func openCalendarPrivacySettings() {
        calendarMessage = "请在系统设置中开启日历权限"

        let privacyURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
        let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security")

        if let privacyURL, NSWorkspace.shared.open(privacyURL) {
            return
        }

        if let settingsURL {
            NSWorkspace.shared.open(settingsURL)
        }
    }

    private func openCalendarApp() {
        holidayCalendarMessage = "请在 Apple 日历左侧列表中开启节假日日历"

        if let calendarURL = URL(string: "ical://") {
            NSWorkspace.shared.open(calendarURL)
        } else {
            let calendarAppURL = URL(fileURLWithPath: "/System/Applications/Calendar.app")
            NSWorkspace.shared.openApplication(
                at: calendarAppURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
        }
    }

    private func refreshHolidayCalendarData() {
        isRefreshingCalendar = true
        holidayCalendarMessage = nil

        HolidayEventSync.shared.requestAccessAndRefresh { granted in
            authorizationStatus = HolidayEventSync.shared.authorizationStatus
            refreshHolidayCalendarNames()
            refreshPreview()
            isRefreshingCalendar = false
            holidayCalendarMessage = granted
                ? (holidayCalendarNames.isEmpty ? "还没检测到节假日日历" : "已刷新节假日数据")
                : "未获得日历权限"
        }
    }

    private func requestCalendarAccess() {
        isRefreshingCalendar = true
        calendarMessage = nil

        HolidayEventSync.shared.requestAccessAndRefresh { granted in
            authorizationStatus = HolidayEventSync.shared.authorizationStatus
            refreshHolidayCalendarNames()
            refreshPreview()
            isRefreshingCalendar = false
            calendarMessage = granted ? "已刷新小组件数据" : "未获得日历权限"
        }
    }

    private func forceReloadWidgets() {
        CalendarEventCache.updateRefreshToken()
        WidgetCenter.shared.reloadTimelines(ofKind: CalendarWidgetIdentity.kind)
        WidgetCenter.shared.reloadAllTimelines()
        widgetRefreshMessage = "已请求刷新，稍候片刻生效。"
        refreshPreview()
    }

    private func openGitHubRepository() {
        if let url = URL(string: "https://github.com/akmumu/ttcalendar") {
            NSWorkspace.shared.open(url)
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.21"
    }
}

private enum DashboardPalette {
    static let windowBackground = Color(light: 0xFFFFFF, dark: 0x111318)
    static let sidebarBackground = Color(light: 0xF6F7F8, dark: 0x171A20)
    static let cardBackground = Color(light: 0xFFFFFF, dark: 0x20242B)
    static let divider = Color(light: 0xE5E5E7, dark: 0x343A44)
    static let primaryText = Color(light: 0x1D1D1F, dark: 0xF5F5F7)
    static let secondaryText = Color(light: 0x6E6E73, dark: 0xA7ADB8)
    static let accent = Color(hex: 0x007AFF)
    static let success = Color(hex: 0x34C759)
    static let danger = Color(hex: 0xFF3B30)
    static let warning = Color(hex: 0xFF9500)

    static let appBackground = windowBackground
    static let previewBackground = windowBackground
    static let subtleFill = Color(light: 0xF6F7F8, dark: 0x2A2F38)
    static let listHover = Color(light: 0xF2F2F7, dark: 0x2F3540)
}

private extension Color {
    init(light: UInt, dark: UInt, opacity: Double = 1) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            let hex = bestMatch == .darkAqua ? dark : light
            return NSColor(hex: hex, opacity: opacity)
        })
    }

    init(hex: UInt, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255

        self.init(red: red, green: green, blue: blue, opacity: opacity)
    }
}

private extension NSColor {
    convenience init(hex: UInt, opacity: Double = 1) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255

        self.init(srgbRed: red, green: green, blue: blue, alpha: CGFloat(opacity))
    }
}

private struct DashboardMaterialCard: ViewModifier {
    var radius: CGFloat = 10

    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(DashboardPalette.cardBackground, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(
                color: .black.opacity(isHovered ? 0.18 : 0.10),
                radius: isHovered ? 18 : 10,
                x: 0,
                y: isHovered ? 10 : 5
            )
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.16)) {
                    isHovered = hovering
                }
            }
    }
}

private extension View {
    func dashboardMaterialCard(radius: CGFloat = 10) -> some View {
        modifier(DashboardMaterialCard(radius: radius))
    }
}

private struct DashboardHoverListBackground: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? DashboardPalette.listHover : Color.clear)
            )
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.12)) {
                    isHovered = hovering
                }
            }
    }
}

private extension View {
    func dashboardHoverListBackground() -> some View {
        modifier(DashboardHoverListBackground())
    }
}

private struct DashboardHoverScale: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.04 : 1)
            .animation(.easeOut(duration: 0.14), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

private extension View {
    func dashboardHoverScale() -> some View {
        modifier(DashboardHoverScale())
    }
}

private struct DashboardSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DashboardPalette.secondaryText)
                .textCase(.uppercase)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                content()
            }
            .background(DashboardPalette.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 12)
        }
    }
}

private struct DashboardDivider: View {
    var body: some View {
            Rectangle()
                .fill(DashboardPalette.divider)
                .frame(height: 1)
            .padding(.vertical, 8)
            .padding(.horizontal, 20)
    }
}

private struct DashboardListDivider: View {
    var body: some View {
        Rectangle()
            .fill(DashboardPalette.divider)
            .frame(height: 1)
            .padding(.leading, 48)
    }
}

private struct StatusListRow: View {
    let systemName: String
    let title: String
    let value: String
    let statusSystemName: String
    let statusTint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DashboardPalette.accent)
                .frame(width: 26, height: 26)

            Text(title)
                .font(.callout)
                .foregroundStyle(DashboardPalette.primaryText)

            Spacer(minLength: 8)

            Text(value)
                .font(.callout)
                .foregroundStyle(DashboardPalette.secondaryText)
                .lineLimit(1)

            Image(systemName: statusSystemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(statusTint)
                .frame(width: 18, height: 18)
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .dashboardHoverListBackground()
        .accessibilityElement(children: .combine)
    }
}

private struct DashboardToolbarButton: View {
    let systemName: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .labelStyle(.iconOnly)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .dashboardHoverScale()
    }
}

private struct WidgetSetupGuide: View {
    let onOpenDetail: () -> Void

    var body: some View {
        Button(action: onOpenDetail) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.grid.2x2")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DashboardPalette.accent)
                    .frame(width: 26, height: 26)

                Text("添加桌面小组件")
                    .font(.callout)
                    .foregroundStyle(DashboardPalette.primaryText)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .dashboardHoverListBackground()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

private struct ActionListRow: View {
    let systemName: String
    let title: String
    let subtitle: String
    var tint: Color = DashboardPalette.accent
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isDisabled ? DashboardPalette.secondaryText : tint)
                    .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout)
                        .foregroundStyle(DashboardPalette.primaryText)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(DashboardPalette.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .frame(height: 50)
            .dashboardHoverListBackground()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

private struct SettingsDetailView: View {
    let accessIcon: String
    let accessTitle: String
    let accessSubtitle: String
    let isAccessDisabled: Bool
    let holidaySubtitle: String
    let isHolidayDisabled: Bool
    let isCalendarDisabled: Bool
    let widgetSubtitle: String
    let statusMessage: String?
    let statusMessageColor: AnyShapeStyle
    let onAccess: () -> Void
    let onRefreshHoliday: () -> Void
    let onOpenCalendar: () -> Void
    let onRefreshWidgets: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 0) {
                ActionListRow(
                    systemName: accessIcon,
                    title: accessTitle,
                    subtitle: accessSubtitle,
                    isDisabled: isAccessDisabled,
                    action: onAccess
                )

                DashboardListDivider()

                ActionListRow(
                    systemName: "arrow.clockwise",
                    title: "重新检测节假日",
                    subtitle: holidaySubtitle,
                    isDisabled: isHolidayDisabled,
                    action: onRefreshHoliday
                )

                DashboardListDivider()

                ActionListRow(
                    systemName: "calendar",
                    title: "打开系统日历",
                    subtitle: "管理本机节假日日历来源",
                    isDisabled: isCalendarDisabled,
                    action: onOpenCalendar
                )

                DashboardListDivider()

                ActionListRow(
                    systemName: "arrow.triangle.2.circlepath",
                    title: "刷新桌面小组件",
                    subtitle: widgetSubtitle,
                    tint: DashboardPalette.accent,
                    action: onRefreshWidgets
                )
            }
            .padding(.vertical, 4)
            .dashboardMaterialCard(radius: 10)

            if let statusMessage {
                Text(statusMessage)
                    .font(.callout)
                    .foregroundStyle(statusMessageColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DashboardPalette.subtleFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}

private struct WidgetSetupDetailView: View {
    private let steps: [(String, String, String)] = [
        ("1", "打开桌面编辑", "在桌面空白处右键，选择“编辑小组件”。"),
        ("2", "搜索抬头日历", "在小组件选择器搜索框里输入“抬头日历”。"),
        ("3", "选择尺寸", "大型显示单月，超大型显示本月和下月。"),
        ("4", "添加到桌面", "拖到桌面或点添加，完成后可返回本应用刷新。")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 14) {
                        Text(step.0)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(DashboardPalette.accent)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(DashboardPalette.accent.opacity(0.12)))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.1)
                                .font(.headline)
                                .foregroundStyle(DashboardPalette.primaryText)

                            Text(step.2)
                                .font(.callout)
                                .foregroundStyle(DashboardPalette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)

                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(DashboardPalette.divider)
                            .frame(height: 1)
                            .padding(.leading, 64)
                    }
                }
            }
            .dashboardMaterialCard(radius: 10)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DashboardPalette.accent)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text("添加后无需保持本应用运行")
                        .font(.callout.weight(.semibold))

                    Text("桌面小组件会读取本机缓存和自定义日期。若刚添加后还没更新，可回到控制中心点击“刷新桌面小组件”。")
                        .font(.caption)
                        .foregroundStyle(DashboardPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(DashboardPalette.subtleFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private struct DashboardWidgetPreview: View {
    let monthAnchorDate: Date
    let todayDate: Date
    let monthOffset: Int
    let onPreviousMonth: () -> Void
    let onCurrentMonth: () -> Void
    let onNextMonth: () -> Void

    private var month: CalendarMonth {
        CalendarContent.month(containing: monthAnchorDate, today: todayDate)
    }

    private var nextMonth: CalendarMonth {
        CalendarContent.month(containing: CalendarContent.addingMonths(1, to: monthAnchorDate), today: todayDate)
    }

    private var todayInfo: TodayInfo {
        CalendarContent.todayInfo(for: todayDate)
    }

    private var highlights: UpcomingHighlights {
        CalendarContent.upcomingHighlights(after: todayDate)
    }

    var body: some View {
        let monthDays = month.daysWithoutCompactTrailingOutsideWeek
        let nextMonthDays = nextMonth.daysWithoutCompactTrailingOutsideWeek
        let showsBottomRow = monthDays.count <= 35 && nextMonthDays.count <= 35
        let customSpecialDay = highlights.nextCustomSpecialDay

        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                DashboardToolbarButton(systemName: "chevron.left", title: "上个月", action: onPreviousMonth)
                    .help("上个月")

                DashboardToolbarButton(systemName: "circle.grid.2x1.left.filled", title: "本月", action: onCurrentMonth)
                    .disabled(monthOffset == 0)
                    .help(monthOffset == 0 ? "当前已是本月" : "回到本月")

                DashboardToolbarButton(systemName: "chevron.right", title: "下个月", action: onNextMonth)
                    .help("下个月")

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    DashboardMonthPanel(month: month, days: monthDays)
                    DashboardMonthPanel(month: nextMonth, days: nextMonthDays)
                }

                if showsBottomRow {
                    DashboardExtraLargeBottomRow(
                        leftDays: month.compactTrailingCurrentMonthDays,
                        rightDays: nextMonth.compactTrailingCurrentMonthDays,
                        todayInfo: customSpecialDay != nil ? nil : todayInfo,
                        customSpecialDay: customSpecialDay,
                        festival: highlights.nextFestival,
                        solarTerm: highlights.nextSolarTerm
                    )
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.985)))
            .animation(.spring(response: 0.34, dampingFraction: 0.84), value: monthOffset)
        }
        .padding(18)
        .dashboardMaterialCard(radius: 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

}

private struct DashboardMonthPanel: View {
    let month: CalendarMonth
    let days: [CalendarDay]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(month.title)
                .font(.headline)
                .foregroundStyle(DashboardPalette.primaryText)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(month.weekdaySymbols, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DashboardPalette.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(days) { day in
                    WidgetDayCell(day: day)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct DashboardExtraLargeBottomRow: View {
    let leftDays: [CalendarDay]
    let rightDays: [CalendarDay]
    let todayInfo: TodayInfo?
    let customSpecialDay: NextSpecialDay?
    let festival: NextSpecialDay?
    let solarTerm: NextSpecialDay?

    var body: some View {
        GeometryReader { proxy in
            let panelSpacing: CGFloat = 16
            let columnSpacing: CGFloat = 4
            let panelWidth = (proxy.size.width - panelSpacing) / 2
            let columnWidth = (panelWidth - columnSpacing * 6) / 7
            let leftWidth = overflowWidth(for: leftDays.count, columnWidth: columnWidth, spacing: columnSpacing)
            let rightWidth = overflowWidth(for: rightDays.count, columnWidth: columnWidth, spacing: columnSpacing)
            let leadingInset = leftWidth > 0 ? leftWidth + panelSpacing : 0
            let trailingInset = rightWidth > 0 ? rightWidth + panelSpacing : 0

            ZStack {
                DashboardExtraLargeInfoBar(
                    todayInfo: todayInfo,
                    customSpecialDay: customSpecialDay,
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

private struct DashboardExtraLargeInfoBar: View {
    let todayInfo: TodayInfo?
    let customSpecialDay: NextSpecialDay?
    let festival: NextSpecialDay?
    let solarTerm: NextSpecialDay?

    var body: some View {
        HStack(spacing: 8) {
            if let todayInfo {
                DashboardExtraLargeInfoItem(
                    systemName: "calendar",
                    title: "今天",
                    value: todayInfo.displayText,
                    detail: "\(todayInfo.dateText) \(todayInfo.weekdayText)",
                    accent: DashboardPalette.accent
                )
            } else if let customSpecialDay {
                DashboardExtraLargeInfoItem(
                    systemName: "star.fill",
                    title: customSpecialDay.name,
                    value: customSpecialDay.isToday ? "就是今天" : "还有 \(customSpecialDay.daysRemaining) 天",
                    detail: customSpecialDay.dateText,
                    accent: customSpecialDay.customDateCategory?.categoryAccentColor ?? DashboardPalette.accent
                )
            }

            if let festival {
                DashboardExtraLargeInfoItem(
                    systemName: "timer",
                    title: festival.name,
                    value: festival.isToday ? "就是今天" : "还有 \(festival.daysRemaining) 天",
                    detail: festival.dateText,
                    accent: DashboardPalette.danger
                )
            }

            if let solarTerm {
                DashboardExtraLargeInfoItem(
                    systemName: "leaf",
                    title: solarTerm.name,
                    value: solarTerm.isToday ? "就是今天" : "还有 \(solarTerm.daysRemaining) 天",
                    detail: solarTerm.dateText,
                    accent: DashboardPalette.success
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 36)
    }
}

private struct DashboardExtraLargeInfoItem: View {
    let systemName: String
    let title: String
    let value: String
    let detail: String
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
                    .foregroundStyle(DashboardPalette.primaryText)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(value)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                        .lineLimit(1)

                    Text(detail)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(DashboardPalette.secondaryText)
                        .lineLimit(1)
                }
            }
            .minimumScaleFactor(0.82)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(DashboardPalette.subtleFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(accent.opacity(0.14), lineWidth: 1)
                )
        )
    }
}
