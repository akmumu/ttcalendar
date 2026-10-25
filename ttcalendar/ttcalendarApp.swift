//
//  ttcalendarApp.swift
//  ttcalendar
//
//  Created by zhangqinglong on 2026/6/15.
//

import SwiftUI
import AppKit
import WidgetKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        WidgetPreferences.shared.migrateLegacyData()
        DateReminderService.shared.start()
        AppInstallRefreshCoordinator.refreshOnLaunch()
        HolidayEventSync.shared.refreshAroundToday {
            AppInstallRefreshCoordinator.reloadWidgetsRepeatedly()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        DateReminderService.shared.refresh()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard DateReminderService.shared.isUpdating else { return .terminateNow }
        Task {
            await DateReminderService.shared.finishPendingUpdates()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

enum AppInstallRefreshCoordinator {
    private static let lastOpenedBuildKey = "lastOpenedBuild"
    private static var pendingReloads: [DispatchWorkItem] = []

    static func refreshOnLaunch() {
        let currentBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""

        let defaults = WidgetPreferences.shared
        if !currentBuild.isEmpty, defaults.string(forKey: lastOpenedBuildKey) != currentBuild {
            WidgetMonthNavigation.reset()
            defaults.set(currentBuild, forKey: lastOpenedBuildKey)
        }

        reloadWidgetsRepeatedly()
    }

    static func reloadWidgetsRepeatedly() {
        pendingReloads.forEach { $0.cancel() }
        pendingReloads.removeAll()
        reloadWidgets()

        for delay in [1.5, 5.0, 12.0] {
            let work = DispatchWorkItem {
                reloadWidgets()
            }
            pendingReloads.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    private static func reloadWidgets() {
        // Requesting a timeline does not require access to the widget's files.
        WidgetCenter.shared.reloadTimelines(ofKind: CalendarWidgetIdentity.kind)
    }
}

@main
struct ttcalendarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var updaterViewModel = UpdaterViewModel()

    var body: some Scene {
        WindowGroup("抬头日历") {
            ContentView()
                .environmentObject(updaterViewModel)
        }
        .defaultSize(width: 1160, height: 700)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("检查更新…") {
                    updaterViewModel.checkForUpdates()
                }
                .disabled(!updaterViewModel.canCheckForUpdates)
            }
        }
    }
}
