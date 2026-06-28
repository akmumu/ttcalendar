//
//  ContentView.swift
//  ttcalendar
//
//  Created by zhangqinglong on 2026/6/15.
//

import EventKit
import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var updaterViewModel: UpdaterViewModel
    @State private var authorizationStatus = HolidayEventSync.shared.authorizationStatus
    @State private var holidayCalendarNames = HolidayEventSync.shared.holidayCalendarNames
    @State private var isRefreshingCalendar = false
    @State private var calendarMessage: String?
    @State private var holidayCalendarMessage: String?

    private let updates = [
        "修复 Mac 睡眠或关机跨天后，小组件可能继续显示旧日期的问题。",
        "小组件会提前生成未来多天时间线，今天高亮和今日信息会按对应日期刷新。",
        "优化小组件月份切换和回到本月按钮，改为后台执行并扩大点击区域。",
        "调试安装脚本会先停止旧的小组件扩展进程，避免系统继续使用旧缓存。",
        "主 App 启动和小组件操作时会写入刷新标记，帮助 WidgetKit 替换旧视图。"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                widgetPreview
                widgetGuide
                customDateManagement
                calendarAccess
                holidayCalendarGuide
                buildInfo
                updateNotes
                footer
                Spacer(minLength: 0)
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 640, minHeight: 720)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            refreshAuthorizationStatus()
            refreshHolidayCalendarNames()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshAuthorizationStatus()
            refreshHolidayCalendarNames()
        }
    }

    private var header: some View {
        HStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text("抬头日历")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))

                Text("桌面小组件日历")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var widgetPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(systemName: "macwindow", title: "小组件预览")

            Image("WidgetPreview")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)
                .accessibilityLabel("抬头日历小组件预览图")
        }
    }

    private var widgetGuide: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(systemName: "rectangle.grid.2x2", title: "怎么使用")

            Text("在桌面空白处右键，选择编辑小组件，搜索抬头日历，然后添加大型或超大型小组件。")
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text("大型显示单月，超大型显示本月和下月。小组件数据会读取本机日历中的节假日信息，并补充农历、节气和常见节日。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("添加小组件后即可一直显示，无需保持本应用启动，也不用让它在后台常驻。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var customDateManagement: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(systemName: "star.circle.fill", title: "自定义特殊日期")

            Text("添加你的重要日子，如生日、会议、纪念日等。这些日期会在日历中以浅紫色背景显示，并支持倒计时。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            CustomDateManagementView()
                .padding(.top, 8)
        }
    }

    private var buildInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(systemName: "hammer", title: "版本信息")

            VStack(spacing: 8) {
                InfoRow(label: "版本", value: appVersion)
                InfoRow(label: "构建时间", value: buildTime)
            }

            Button {
                updaterViewModel.checkForUpdates()
            } label: {
                Label("检查更新", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!updaterViewModel.canCheckForUpdates)
            .padding(.top, 2)
        }
    }

    private var calendarAccess: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                SectionTitle(systemName: "calendar.badge.checkmark", title: "日历权限")

                Spacer(minLength: 12)

                AccessStatusBadge(status: authorizationStatus)
            }

            Text(accessDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    performAccessAction()
                } label: {
                    Label(accessButtonTitle, systemImage: accessButtonIcon)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRefreshingCalendar || isAccessActionDisabled)

                if isRefreshingCalendar {
                    ProgressView()
                        .controlSize(.small)
                }

                if let calendarMessage {
                    Text(calendarMessage)
                        .font(.callout)
                        .foregroundStyle(messageColor)
                }
            }
        }
    }

    private var holidayCalendarGuide: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                SectionTitle(systemName: "calendar.day.timeline.left", title: "节假日日历数据")

                Spacer(minLength: 12)

                HolidayCalendarStatusBadge(
                    hasCalendarAccess: hasCalendarAccess,
                    hasHolidayCalendars: !holidayCalendarNames.isEmpty
                )
            }

            Text(holidayCalendarDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !holidayCalendarNames.isEmpty {
                Text("已检测到：\(holidayCalendarNames.joined(separator: "、"))")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.green)
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                Button {
                    openCalendarApp()
                } label: {
                    Label("打开 Apple 日历", systemImage: "calendar")
                }
                .disabled(!hasCalendarAccess)

                Button {
                    refreshHolidayCalendarData()
                } label: {
                    Label("重新检测", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRefreshingCalendar || !hasCalendarAccess)

                if let holidayCalendarMessage {
                    Text(holidayCalendarMessage)
                        .font(.callout)
                        .foregroundStyle(holidayCalendarNames.isEmpty ? .orange : .green)
                }
            }
        }
    }

    private var updateNotes: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(systemName: "sparkles", title: "最新更新")

            VStack(alignment: .leading, spacing: 8) {
                ForEach(updates, id: \.self) { update in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.green)

                        Text(update)
                            .font(.callout)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Spacer()

            Text("create by akmumu")
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)

            Link(destination: URL(string: "https://github.com/akmumu/ttcalendar")!) {
                Label("GitHub", systemImage: "link")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.secondary)
            .help("打开 GitHub 仓库")
        }
        .padding(.top, 4)
    }

    private var accessDescription: String {
        switch authorizationStatus {
        case .fullAccess, .authorized:
            return "已获得日历权限，已同步本机节假日日历。点击按钮可重新读取并刷新桌面小组件。"
        case .notDetermined:
            return "首次使用前需要授权读取日历，否则小组件只能显示内置农历、节气和有限节假日。"
        case .denied:
            return "日历权限已关闭。点击按钮可直接打开系统设置，请在隐私与安全性里允许抬头日历访问日历。"
        case .restricted:
            return "当前系统限制了日历访问，暂时无法读取本机节假日日历。"
        case .writeOnly:
            return "当前只有写入权限，仍需要完整日历访问权限才能读取节假日。"
        @unknown default:
            return "无法确认日历权限状态，请尝试授权后重新读取。"
        }
    }

    private var holidayCalendarDescription: String {
        guard hasCalendarAccess else {
            return "本应用读取的是系统自带日历里的节假日数据。请先开启日历权限，再检查 Apple 日历中是否显示“节假日”日历。"
        }

        if holidayCalendarNames.isEmpty {
            return "本应用读取的是 Apple 日历里已经显示的节假日数据。系统不允许第三方应用替你勾选“节假日”日历，请打开 Apple 日历，在日历列表中开启“节假日”或“假日”日历后返回重新检测。"
        }

        return "本应用会读取这些系统日历中的节假日数据，并刷新到桌面小组件。"
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
            return .green
        case .denied, .restricted:
            return .red
        default:
            return .secondary
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

    private func refreshAuthorizationStatus() {
        authorizationStatus = HolidayEventSync.shared.authorizationStatus
    }

    private func refreshHolidayCalendarNames() {
        holidayCalendarNames = HolidayEventSync.shared.holidayCalendarNames
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
            NSWorkspace.shared.launchApplication("Calendar")
        }
    }

    private func refreshHolidayCalendarData() {
        isRefreshingCalendar = true
        holidayCalendarMessage = nil

        HolidayEventSync.shared.requestAccessAndRefresh { granted in
            authorizationStatus = HolidayEventSync.shared.authorizationStatus
            refreshHolidayCalendarNames()
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
            isRefreshingCalendar = false
            calendarMessage = granted ? "已刷新小组件数据" : "未获得日历权限"
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.16"
    }

    private var buildTime: String {
        let date = Bundle.main.executableURL
            .flatMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
            ?? Date()

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

private struct SectionTitle: View {
    let systemName: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemName)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            Text(title)
                .font(.title2.weight(.semibold))
        }
    }
}

private struct AccessStatusBadge: View {
    let status: EKAuthorizationStatus

    var body: some View {
        Label(title, systemImage: systemName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(backgroundColor, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(borderColor, lineWidth: 1)
            }
            .accessibilityLabel("日历权限状态：\(title)")
    }

    private var title: String {
        switch status {
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

    private var systemName: String {
        switch status {
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

    private var foregroundColor: Color {
        switch status {
        case .fullAccess, .authorized:
            return .green
        case .denied, .restricted:
            return .red
        case .writeOnly:
            return .orange
        default:
            return .secondary
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.12)
    }

    private var borderColor: Color {
        foregroundColor.opacity(0.2)
    }
}

private struct HolidayCalendarStatusBadge: View {
    let hasCalendarAccess: Bool
    let hasHolidayCalendars: Bool

    var body: some View {
        Label(title, systemImage: systemName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(foregroundColor.opacity(0.12), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(foregroundColor.opacity(0.2), lineWidth: 1)
            }
            .accessibilityLabel("节假日日历状态：\(title)")
    }

    private var title: String {
        if !hasCalendarAccess {
            return "待授权"
        }

        return hasHolidayCalendars ? "已检测到" : "未检测到"
    }

    private var systemName: String {
        if !hasCalendarAccess {
            return "questionmark.circle.fill"
        }

        return hasHolidayCalendars ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
    }

    private var foregroundColor: Color {
        if !hasCalendarAccess {
            return .secondary
        }

        return hasHolidayCalendars ? .green : .orange
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)

            Text(value)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
    }
}
