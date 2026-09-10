# 发布流程

这份流程保留当前习惯：先用 `Scripts/install_debug_widget.sh` 做本地功能测试，再用 Xcode Archive 导出 App，最后打包 DMG 并发布 Sparkle appcast。

1.23 默认支持免付费证书的 DMG 分发。主应用不启用 App Sandbox，小组件保留沙盒；两者通过小组件自身容器中的文件共享假期、自定义日期和月份状态，不依赖 App Group。旧版 App Group 缓存由主应用迁移，迁移失败不会删除原数据。

打包脚本检查主应用和小组件的 `WidgetDataTransport=widgetContainer-v1`，仅对这种架构生成 ad-hoc 包，避免把 1.22 的 App Group 架构误打成无法读取数据的包。用户拖入 Applications 后，首次启动可能需要在系统设置中允许打开，并允许日历和小组件数据访问。不要求关闭 SIP、Gatekeeper 或授予完全磁盘访问权限。

Developer ID 签名和公证仍可选，用于减少系统首次启动提示。Sparkle 的更新签名保持独立，继续使用原有 EdDSA 密钥。

## 0. 首次发布前生成 Sparkle 密钥

当前使用 Keychain account `akmumu.ttcalendar` 保存 Sparkle EdDSA 私钥，公钥为：

```text
CednorgFOaxIy8wQb0PNbx+OhsiGsVJtB+PvgExrtbM=
```

新电脑首次发布前，必须从当前电脑导出并导入这把私钥，不能直接生成新密钥。

```sh
Scripts/generate_sparkle_keys.sh
```

脚本会把私钥保存在 macOS Keychain 下，并更新 `SUPublicEDKey`。私钥不要提交到 Git，也不要放进 release 目录。

1.22 因原私钥无法恢复，轮换到了上述新密钥。1.21 及更早版本仍信任旧公钥，因此无法通过应用内更新跨越这次轮换，必须手动安装一次 1.22。安装 1.22 后，后续版本继续使用 `akmumu.ttcalendar` 这把密钥即可恢复自动更新。

旧公钥仅保留用于记录：

```text
prXVolYqRBZ2dxSMY3Ga/pF+AdwrlcCc/XetU/60R2o=
```

迁移到另一台电脑时，先在当前电脑导出：

```sh
"$(Scripts/find_sparkle_tool.sh generate_keys)" --account akmumu.ttcalendar -x sparkle-private-key
```

然后在新电脑导入：

```sh
"$(Scripts/find_sparkle_tool.sh generate_keys)" --account akmumu.ttcalendar -f sparkle-private-key
```

确认导入完成后安全删除导出的私钥文件。

## 1. 开发测试

```sh
Scripts/install_debug_widget.sh
```

确认 App、本机日历同步、小组件刷新和月份切换都正常。

## 2. 更新版本号

在 Xcode 工程里同时递增：

- `MARKETING_VERSION`，例如 `1.14`
- `CURRENT_PROJECT_VERSION`，例如 `14`

Sparkle 主要使用 build 号比较版本，所以 `CURRENT_PROJECT_VERSION` 必须递增。

## 3. 构建免证书版本

```sh
xcodebuild -project ttcalendar.xcodeproj -scheme ttcalendar \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath /private/tmp/ttcalendar-release CODE_SIGNING_ALLOWED=NO build

RELEASE_DIR=/private/tmp/ttcalendar-release/Build/Products/Release Scripts/package_dmg.sh
```

也可以使用 Xcode 导出 App 后交给打包脚本。若选择付费签名路线，在 Xcode 里：

在 Xcode 里：

1. Product -> Archive
2. Organizer -> Distribute App
3. 选择 Developer ID 导出
4. 导出后确保目录形如：

```text
/Users/didi/workspace/apple/release/抬头日历.app
```

选择 Developer ID 路线时，导出后完成 notarization 和 stapling；默认免证书路线不需要此步骤。

## 4. 打包 DMG

默认免证书打包（仅修改临时副本，保留原构建）：

```sh
Scripts/package_dmg.sh
```

脚本默认输入：

```text
/Users/didi/workspace/apple/release/抬头日历.app
```

默认输出：

```text
/Users/didi/workspace/apple/ttcalendar.dmg
```

如果要覆盖已有 DMG：

```sh
OVERWRITE_DMG=1 Scripts/package_dmg.sh
```

发布前必须实际验证已打包安装的桌面小组件能显示 Apple 日历的休假及调休标记。仅通过编译、主应用预览或 Sparkle 签名校验不代表小组件具备共享容器访问权限。

## 5. 可选：Developer ID notarized 发布

如果有付费 Apple Developer Program，并且要做正式外部分发，第一次使用前先把 Apple notarization 凭据保存到 Keychain。`APPLE_ID` 使用 Apple Developer 账号邮箱，`TEAM_ID` 使用开发者团队 ID，密码使用 Apple ID 的 app-specific password：

```sh
xcrun notarytool store-credentials ttcalendar-notary --apple-id APPLE_ID --team-id TEAM_ID
```

之后每次发布，在打包 DMG 前执行：

```sh
Scripts/notarize_app.sh
```

完成后用严格检查打包：

```sh
STRICT_RELEASE_CHECKS=1 Scripts/package_dmg.sh
```

如果看到 `does not have a ticket stapled to it`，说明还没有执行 notarization，或者 notarization 成功后没有 staple。

如果看到 `CSSMERR_TP_NOT_TRUSTED` 或 `Authority=(unavailable)`，说明当前导出的 App 签名链不可信，需要重新用有效的 Developer ID Application 证书导出。

## 6. 创建 GitHub Release

在 GitHub 仓库 `akmumu/ttcalendar` 创建 tag，例如：

```text
1.14
```

上传 DMG：

```text
ttcalendar.dmg
```

## 7. 生成 Sparkle appcast

可选：先写发布说明，文件名按版本号放：

```text
release-notes/1.14.html
```

然后生成 appcast：

```sh
Scripts/update_appcast.sh
```

脚本默认会：

- 从 `/Users/didi/workspace/apple/ttcalendar.dmg` 读取 DMG
- 用 Keychain 里的 `akmumu.ttcalendar` 私钥签名
- 生成或更新 `docs/appcast.xml`
- 默认下载地址前缀为 `https://github.com/akmumu/ttcalendar/releases/download/版本号/`

如果 tag 或 DMG 地址不同：

```sh
RELEASE_TAG=1.14 Scripts/update_appcast.sh
```

也可以直接覆盖完整下载前缀，注意结尾 `/` 可省略，脚本会自动补上：

```sh
DOWNLOAD_URL_PREFIX=https://github.com/akmumu/ttcalendar/releases/download/1.14 Scripts/update_appcast.sh
```

## 8. 发布 GitHub Pages

把仓库推到 GitHub，并开启 GitHub Pages：

- Source: `Deploy from a branch`
- Branch: `main`
- Folder: `/docs`

确认这个地址能访问：

```text
https://akmumu.github.io/ttcalendar/appcast.xml
```

这个地址必须和 `ttcalendar/Info.plist` 里的 `SUFeedURL` 一致。

## 9. 更新测试

最可靠的测试方式：

1. 安装旧版本，例如 build `13`
2. 发布新版本，例如 build `14`
3. 打开旧版本，点击“检查更新”
4. 确认 Sparkle 能看到新版本、下载 DMG、完成替换

如果检查不到更新，优先检查：

- `docs/appcast.xml` 是否已经发布到 GitHub Pages
- GitHub Release asset 的下载地址是否能直接访问
- `sparkle:version` 是否大于本地 `CFBundleVersion`
- `SUPublicEDKey` 是否和 Keychain 里的私钥匹配

如果下载进度完成后才报“更新错误”，优先检查 sandbox + Sparkle 的安装通信配置。主 App 的 entitlements 必须包含：

```xml
<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
<array>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)-spks</string>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)-spki</string>
</array>
```

缺少这两个临时例外时，sandbox 内的 App 可以下载更新，但可能无法和 Sparkle installer 工具完成安装通信。已经发布且缺少这两个 entitlements 的旧版本，通常无法靠 appcast 修复，需要用户手动下载新 DMG 覆盖安装一次。
