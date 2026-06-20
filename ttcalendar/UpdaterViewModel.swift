//
//  UpdaterViewModel.swift
//  ttcalendar
//
//  封装 Sparkle 的更新控制器，供菜单与界面调用。
//

import Combine
import Sparkle
import SwiftUI

/// 桥接 Sparkle 的更新器，发布「能否检查更新」状态供 SwiftUI 绑定。
final class UpdaterViewModel: ObservableObject {
    private let updaterController: SPUStandardUpdaterController

    /// 是否允许手动检查更新（更新进行中时由 Sparkle 置为 false）。
    @Published var canCheckForUpdates = false

    init() {
        // startingUpdater: true 会在启动后按 Info.plist 的设置自动检查更新。
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    /// 手动检查更新，弹出 Sparkle 的标准更新界面。
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
