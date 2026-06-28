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
        AppInstallRefreshCoordinator.refreshOnLaunch()
        HolidayEventSync.shared.refreshAroundToday {
            AppInstallRefreshCoordinator.reloadWidgetsRepeatedly()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

private enum AppInstallRefreshCoordinator {
    private static let lastOpenedBuildKey = "lastOpenedBuild"

    static func refreshOnLaunch() {
        let currentBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""

        let defaults = UserDefaults(suiteName: CalendarEventCache.appGroupIdentifier) ?? .standard
        if !currentBuild.isEmpty, defaults.string(forKey: lastOpenedBuildKey) != currentBuild {
            WidgetMonthNavigation.reset()
            defaults.set(currentBuild, forKey: lastOpenedBuildKey)
        }

        reloadWidgetsRepeatedly()
    }

    static func reloadWidgetsRepeatedly() {
        reloadWidgets()

        for delay in [1.5, 5.0, 12.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                reloadWidgets()
            }
        }
    }

    private static func reloadWidgets() {
        CalendarEventCache.updateRefreshToken()
        WidgetCenter.shared.reloadTimelines(ofKind: CalendarWidgetIdentity.kind)
        WidgetCenter.shared.reloadAllTimelines()
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
        .defaultSize(width: 620, height: 560)
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
