# 发布流程

这份流程保留当前习惯：先用 `Scripts/install_debug_widget.sh` 做本地功能测试，再用 Xcode Archive 导出 App，最后打包 DMG 并发布 Sparkle appcast。

当前默认按免费分发模式打包：脚本会复制导出的 App，移除 embedded provisioning profile，并重新做 ad-hoc 签名，避免把 Personal Team 的不可验证签名链带进 DMG。用户首次打开时仍可能需要右键打开，或在隐私与安全性里选择仍要打开。

## 0. 首次发布前生成 Sparkle 密钥

当前还没有对应私钥，所以在第一次对外发布前必须生成一套新的 Sparkle EdDSA 密钥，并把新的公钥写进 `ttcalendar/Info.plist`。

```sh
Scripts/generate_sparkle_keys.sh
```

脚本会把私钥保存在 macOS Keychain 下，并更新 `SUPublicEDKey`。私钥不要提交到 Git，也不要放进 release 目录。

已经发布过的 App 不能随意更换 `SUPublicEDKey`。1.13 使用的是默认 Keychain account `ed25519` 对应的公钥，后续版本必须继续用这把钥匙签名：

```text
prXVolYqRBZ2dxSMY3Ga/pF+AdwrlcCc/XetU/60R2o=
```

如果要换 account：

```sh
SPARKLE_KEY_ACCOUNT=akmumu.ttcalendar Scripts/generate_sparkle_keys.sh
```

只有在还没有任何外部版本使用 Sparkle 更新时，才可以换 account 或换公钥。

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

## 3. Archive 并导出 App

在 Xcode 里：

1. Product -> Archive
2. Organizer -> Distribute App
3. 没有付费开发者账号时，选择能导出 `.app` 的方式即可；脚本会为免费分发重新 ad-hoc 签名
4. 导出后确保目录形如：

```text
/Users/didi/workspace/apple/release/抬头日历.app
```

如果有付费 Apple Developer Program，并且希望用户无阻碍打开，再选择 Developer ID 面向外部分发，并完成 notarization 和 stapling。

## 4. 打包 DMG

免费分发默认直接运行：

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

用户如果仍看到系统拦截，优先让用户右键 App 选择打开；如果还是不行，可以清除下载隔离属性：

```sh
xattr -dr com.apple.quarantine /Applications/抬头日历.app
```

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
- 用 Keychain 里的 `ed25519` 私钥签名
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
