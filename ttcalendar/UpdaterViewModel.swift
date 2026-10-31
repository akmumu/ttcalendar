//
//  UpdaterViewModel.swift
//  ttcalendar
//
//  封装 Sparkle 的更新控制器，供菜单与界面调用。
//

import Combine
import Sparkle
import SwiftUI
import WidgetKit

/// 桥接 Sparkle 的更新器，发布「能否检查更新」状态供 SwiftUI 绑定。
@MainActor
final class UpdaterViewModel: NSObject, ObservableObject, SPUUpdaterDelegate {
    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil
    )
    private var subscriptions = Set<AnyCancellable>()

    /// 是否允许手动检查更新（更新进行中时由 Sparkle 置为 false）。
    @Published var canCheckForUpdates = false
    @Published private(set) var availableUpdate: AvailableAppUpdate?
    @Published private(set) var automaticChecks = true
    @Published private(set) var syncMessage: String?

    override init() {
        super.init()
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
        updaterController.updater.publisher(for: \.automaticallyChecksForUpdates)
            .removeDuplicates()
            .sink { [weak self] enabled in
                guard let self else { return }
                self.automaticChecks = enabled
                self.syncSetting(enabled)
            }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.refreshCachedUpdate() }
            .store(in: &subscriptions)
        refreshCachedUpdate()
        updaterController.startUpdater()
    }

    /// 手动检查更新，弹出 Sparkle 的标准更新界面。
    func checkForUpdates() {
        // A deliberate check also lets the user revisit a skipped version.
        WidgetPreferences.shared.set(0, forKey: AppUpdateStore.skippedBuildKey)
        updaterController.checkForUpdates(nil)
    }

    func setAutomaticChecks(_ enabled: Bool) {
        updaterController.updater.automaticallyChecksForUpdates = enabled
    }

    func refreshCachedUpdate() {
        availableUpdate = AppUpdateStore.availableUpdate()
        NSApp.dockTile.badgeLabel = availableUpdate == nil ? nil : "新"
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        guard let build = Int(item.versionString) else { return }
        accept(AvailableAppUpdate(build: build, version: item.displayVersionString))
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        accept(nil)
    }

    func updater(_ updater: SPUUpdater, userDidMake choice: SPUUserUpdateChoice,
                 forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        guard choice == .skip, let build = Int(update.versionString) else { return }
        WidgetPreferences.shared.set(build, forKey: AppUpdateStore.skippedBuildKey)
        availableUpdate = nil
        NSApp.dockTile.badgeLabel = nil
        WidgetCenter.shared.reloadTimelines(ofKind: CalendarWidgetIdentity.kind)
    }

    private func accept(_ update: AvailableAppUpdate?) {
        availableUpdate = update
        NSApp.dockTile.badgeLabel = update == nil ? nil : "新"
        let saved = AppUpdateStore.save(AppUpdateStatus(checkedAt: Date(), latest: update))
        syncMessage = saved ? nil : "更新提示未能同步到小组件：\(WidgetPreferences.shared.lastWriteError ?? "写入失败")"
        WidgetCenter.shared.reloadTimelines(ofKind: CalendarWidgetIdentity.kind)
    }

    private func syncSetting(_ enabled: Bool) {
        let saved = WidgetPreferences.shared.set(enabled ? "on" : "off", forKey: AppUpdateStore.automaticChecksKey)
        syncMessage = saved ? nil : "自动检查设置未能同步到小组件：\(WidgetPreferences.shared.lastWriteError ?? "写入失败")"
        WidgetCenter.shared.reloadTimelines(ofKind: CalendarWidgetIdentity.kind)
    }
}
