# 发布流程

这份流程保留当前习惯：先用 `Scripts/install_debug_widget.sh` 做本地功能测试，再用 Xcode Archive 导出 App，最后打包 DMG 并发布 Sparkle appcast。

## 0. 首次发布前生成 Sparkle 密钥

当前还没有对应私钥，所以在第一次对外发布前必须生成一套新的 Sparkle EdDSA 密钥，并把新的公钥写进 `ttcalendar/Info.plist`。

```sh
Scripts/generate_sparkle_keys.sh
```

脚本会把私钥保存在 macOS Keychain 的 `akmumu.ttcalendar` account 下，并更新 `SUPublicEDKey`。私钥不要提交到 Git，也不要放进 release 目录。

如果要换 account：

```sh
SPARKLE_KEY_ACCOUNT=akmumu.ttcalendar Scripts/generate_sparkle_keys.sh
```

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
3. 选择面向外部分发的签名/导出方式
4. 导出后确保目录形如：

```text
/Users/didi/workspace/apple/release/抬头日历.app
```

如果做正式外部分发，建议使用 Developer ID 签名并完成 notarization，否则用户首次打开可能被 Gatekeeper 拦截。

## 4. 打包 DMG

```sh
Scripts/package_dmg.sh
```

默认输入：

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

## 5. 创建 GitHub Release

在 GitHub 仓库 `akmumu/ttcalendar` 创建 tag，例如：

```text
1.14
```

上传 DMG：

```text
ttcalendar.dmg
```

## 6. 生成 Sparkle appcast

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

## 7. 发布 GitHub Pages

把仓库推到 GitHub，并开启 GitHub Pages：

- Source: `Deploy from a branch`
- Branch: `main`
- Folder: `/docs`

确认这个地址能访问：

```text
https://akmumu.github.io/ttcalendar/appcast.xml
```

这个地址必须和 `ttcalendar/Info.plist` 里的 `SUFeedURL` 一致。

## 8. 更新测试

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
