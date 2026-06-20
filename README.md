# 抬头日历

抬头日历是一款 macOS 桌面小组件日历应用，用来在桌面快速查看本月、下月、农历、节日、节气、周末和调休信息。

应用本体负责权限授权、节假日日历同步、更新检查和使用说明；WidgetKit 小组件负责日历展示、月份切换和近期节日提醒。

![抬头日历小组件截图](ttcalendar/Assets.xcassets/WidgetPreview.imageset/widget-preview.png)

## 下载

[下载最新版 macOS 安装包](https://github.com/akmumu/ttcalendar/releases/latest/download/ttcalendar.dmg)

## 功能

- 大型桌面小组件：展示单月日历、农历、节假日、节气、周末和调休标记。
- 超大型桌面小组件：同时展示本月和下月，并补充今日信息、近期节日和节气提醒。
- 小组件内月份切换：支持上个月、下个月和回到本月。
- Apple 日历同步：读取本机日历中名称包含“节假日”“假日”或 “holiday” 的日历数据，提高调休和休班信息准确度。
- Sparkle 更新：应用内支持手动检查更新。

## 环境

- macOS 26.5 或更高版本
- Xcode 26 或更高版本
- SwiftUI / WidgetKit / AppIntents
- Swift Package 依赖：Sparkle 2.9.3

## 运行

1. 用 Xcode 打开 `ttcalendar.xcodeproj`。
2. 选择 `ttcalendar` scheme。
3. 选择 macOS 目标并运行。
4. 首次启动后，在应用内授权日历访问。
5. 在桌面空白处右键选择“编辑小组件”，搜索“抬头日历”，添加大型或超大型小组件。

## 调试小组件

可以使用脚本构建、安装并注册调试版本：

```sh
Scripts/install_debug_widget.sh
```

脚本会：

- 使用 `xcodebuild` 构建 Debug 版本。
- 验证 app 和 widget extension 签名。
- 安装到 `/Applications/抬头日历.app`。
- 注册 WidgetKit extension。
- 启动应用，并提示重新打开小组件选择器。

可通过环境变量覆盖默认值：

```sh
SCHEME=ttcalendar CONFIGURATION=Debug DERIVED_DATA=/private/tmp/ttcalendar-widget-dev Scripts/install_debug_widget.sh
```

## 发布

发布流程见 `RELEASE.md`。当前流程保留 Xcode Archive 导出 App，再用脚本打包 DMG 和生成 Sparkle appcast：

```sh
Scripts/package_dmg.sh
Scripts/update_appcast.sh
```

首次发布前需要先生成 Sparkle 私钥并写入公钥：

```sh
Scripts/generate_sparkle_keys.sh
```

## 目录结构

```text
.
├── ttcalendar/                 # macOS 应用本体
├── CalendarWidget/             # WidgetKit 小组件扩展
├── Shared/                     # 应用与小组件共用的日历模型、节日、农历和导航逻辑
├── Scripts/                    # 构建、安装和图标生成脚本
├── GeneratedIcon.appiconset/   # 生成的图标资源
└── ttcalendar.xcodeproj/       # Xcode 工程
```

## 关键模块

- `ttcalendar/ContentView.swift`：应用主界面，包含小组件预览、权限状态、节假日日历检测和更新入口。
- `ttcalendar/HolidayEventSync.swift`：读取 Apple 日历事件，缓存节假日和调休数据，并刷新小组件时间线。
- `ttcalendar/UpdaterViewModel.swift`：封装 Sparkle 更新检查。
- `CalendarWidget/CalendarWidget.swift`：WidgetKit 入口、时间线 provider、月历布局和小组件交互按钮。
- `Shared/CalendarContent.swift`：生成月历数据、今日信息、近期节日和节气提醒。
- `Shared/WidgetMonthNavigation.swift`：小组件月份偏移状态。
- `Shared/CalendarWidgetIdentity.swift`：小组件 kind 标识。

## 日历数据说明

抬头日历会优先读取本机 Apple 日历中的节假日数据，并结合内置农历、节日和节气逻辑生成小组件内容。如果没有授予日历权限，应用仍可显示内置数据，但调休和休班信息可能不如系统节假日日历完整。

## 图标生成

项目包含图标生成脚本：

```sh
swift Scripts/generate_app_icon.swift
```

生成结果会输出到 `GeneratedIcon.appiconset/`，可按需同步到 app 或 widget 的 `Assets.xcassets/AppIcon.appiconset/`。

## 版本

当前工程版本：

- Marketing Version：`1.13`
- Build：`13`
