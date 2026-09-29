# 抬头日历发布 SOP

适用于当前 macOS App + WidgetKit + Sparkle + GitHub Releases / Pages 的发布方式。

**顺序：升版 → 测试 → Release 构建 → DMG → Sparkle 签名 → 推送版本标签 → 上传并公开 Release → 推送 main 更新源 → 验证客户端。**

只 push 代码不会上传安装包；只上传 DMG 不会更新客户端的更新源。必须完成两部分。

## 固定配置

| 项目 | 当前值 |
| --- | --- |
| GitHub 仓库 | `akmumu/ttcalendar` |
| 发布分支 / 标签 | `main` / 与版本号相同，例如 `1.25` |
| GitHub Pages | `main` 分支的 `/docs` |
| Sparkle 更新源 | `https://akmumu.github.io/ttcalendar/appcast.xml` |
| Sparkle Keychain account | `akmumu.ttcalendar` |
| App / Widget 版本 | 必须一起修改，Debug / Release 共四处 |
| 系统 / 架构 | macOS 14.0+，Intel + Apple Silicon |
| 分发方式 | ad-hoc 签名，当前没有 Developer ID 公证 |

本次版本为 **1.25 / build 25**。下面用下一版 **1.26 / build 26** 演示；每次先改这两个数字，已发布的版本号、标签和安装包不要重复使用。

本次执行结果见 [1.25 发布验证记录](release-notes/1.25-validation.md)，包含真实客户端升级结果、安装包哈希及尚未完成的通知送达验证。

## 0. 发布环境（新电脑需要准备）

- 安装完整 Xcode 并接受许可；用 Xcode 打开项目，确保 Swift Package 可以解析。
- 安装 `create-dmg`、GitHub CLI 和 Python 3：

```sh
HOMEBREW_NO_INSTALL_CLEANUP=1 brew install create-dmg gh
python3 --version
xcodebuild -version
```

`python3 Scripts/github_cli.py ...` 是本仓库的 GitHub CLI 入口：优先使用 `gh` 自己的登录；否则复用 Git 中 `github.com / akmumu` 的凭据，仅在内存中传递，不输出或保存令牌。缺少登录时执行：

```sh
gh auth login --hostname github.com
```

现有 Sparkle 私钥必须保留在 Keychain。**常规发布不要重新生成密钥。** 核对现有公钥：

```sh
"$(Scripts/find_sparkle_tool.sh generate_keys)" --account akmumu.ttcalendar -p
/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' ttcalendar/Info.plist
```

两者应同为：`CednorgFOaxIy8wQb0PNbx+OhsiGsVJtB+PvgExrtbM=`。

找不到 Sparkle 工具时，在 Xcode 构建一次，或设置 `SPARKLE_BIN=/实际路径/Sparkle/bin`。脚本会查找项目 `DerivedData` 和用户 Xcode DerivedData。

## 1. 同步仓库、升版、写更新说明

在仓库根目录执行。先查看本地改动和远端提交，若远端有新提交，合并后再发布；不要覆盖未提交的工作。

```sh
git status --short
git fetch origin
git log --oneline HEAD..origin/main

export RELEASE_VERSION=1.26
export RELEASE_BUILD=26
export RELEASE_OUTPUT="$PWD/build/releases/$RELEASE_VERSION"
export RELEASE_DERIVED="$PWD/DerivedData/release-$RELEASE_VERSION"
mkdir -p "$RELEASE_OUTPUT"
python3 Scripts/bump_version.py "$RELEASE_VERSION" "$RELEASE_BUILD"
```

`bump_version.py` 一次修改主应用和小组件的四处版本，并拒绝不递增的版本/build。Sparkle 使用 build 比较新旧，不能只改展示版本。

参考 `release-notes/1.25.html`、`release-notes/1.25.md`，为新版本创建：

- `release-notes/$RELEASE_VERSION.html`：客户端更新窗口使用。
- `release-notes/$RELEASE_VERSION.md`：GitHub Release 使用。

## 2. 运行回归测试

```sh
swiftc -module-cache-path /private/tmp/ttcalendar-tests-cache Shared/WidgetPreferences.swift Scripts/test_widget_preferences.swift -o /private/tmp/ttcalendar-storage-tests
/private/tmp/ttcalendar-storage-tests

swiftc -module-cache-path /private/tmp/ttcalendar-tests-cache Shared/WidgetPreferences.swift Shared/DateReminder.swift Shared/CustomSpecialDate.swift ttcalendar/DateReminderPlan.swift Scripts/test_date_reminders.swift -o /private/tmp/ttcalendar-reminder-tests
/private/tmp/ttcalendar-reminder-tests

swiftc -module-cache-path /private/tmp/ttcalendar-tests-cache Shared/WidgetPreferences.swift Shared/DateReminder.swift Shared/CustomSpecialDate.swift ttcalendar/DateReminderPlan.swift ttcalendar/DateReminderService.swift Scripts/test_reminder_service.swift -o /private/tmp/ttcalendar-service-tests
/private/tmp/ttcalendar-service-tests
```

三组应输出 `PASS`。同时检查日期增删改、提醒选项和权限提示。日期计算/模拟通知测试不会实际发送系统通知；新通知功能还需在允许通知的环境中设置一条近未来提醒，验证关闭应用后收到，并验证关闭提醒或删除后不再发送。

需要开发安装时可运行 `Scripts/install_debug_widget.sh`，但它会替换 `/Applications/抬头日历.app`。如果准备验证旧版自动升级，先保留已安装旧版，别提前用开发版替换。

## 3. 构建正式配置，打包 DMG

```sh
xcodebuild -project ttcalendar.xcodeproj -scheme ttcalendar \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath "$RELEASE_DERIVED" CODE_SIGNING_ALLOWED=NO build

RELEASE_DIR="$RELEASE_DERIVED/Build/Products/Release" \
DMG_PATH="$RELEASE_OUTPUT/ttcalendar-$RELEASE_VERSION.dmg" \
Scripts/package_dmg.sh

cp "$RELEASE_OUTPUT/ttcalendar-$RELEASE_VERSION.dmg" "$RELEASE_OUTPUT/ttcalendar.dmg"
```

看到 `BUILD SUCCEEDED` 和 `Created ...dmg` 才继续。打包脚本会复制构建产物后签名，不修改原始构建；App 和小组件都必须使用 `widgetContainer-v1` 数据共享方式。`generic/platform=macOS` 用于生成 Intel + Apple Silicon 通用版本。

上传两个相同内容的文件：版本化文件给 Sparkle，`ttcalendar.dmg` 保持 README 的“最新版下载”链接可用。不要将 DMG 加进 Git，`build/` 已忽略。

若同名 DMG 已存在，先确认它尚未发布；确需重新打包时设置 `OVERWRITE_DMG=1`，之后必须重新生成签名和 appcast。已发布的 DMG 不要覆盖。

## 4. 检查实际打包产物

```sh
hdiutil attach -readonly -nobrowse -mountpoint /private/tmp/ttcalendar-release-check \
  "$RELEASE_OUTPUT/ttcalendar-$RELEASE_VERSION.dmg"

codesign --verify --deep --strict --verbose=2 '/private/tmp/ttcalendar-release-check/抬头日历.app'
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' '/private/tmp/ttcalendar-release-check/抬头日历.app/Contents/Info.plist'
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' '/private/tmp/ttcalendar-release-check/抬头日历.app/Contents/Info.plist'
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' '/private/tmp/ttcalendar-release-check/抬头日历.app/Contents/PlugIns/CalendarWidgetExtension.appex/Contents/Info.plist'
lipo -archs '/private/tmp/ttcalendar-release-check/抬头日历.app/Contents/MacOS/抬头日历'

hdiutil detach /private/tmp/ttcalendar-release-check
```

App/Widget build 必须一致，架构应包含 `x86_64 arm64`。签名检查通过代表包完整，不代表 Developer ID 公证通过。

在测试机/测试账号安装 DMG，检查桌面小组件实际显示休假、调休、自定义日期与月份切换。主应用预览通过不能替代真实小组件验证。已有 1.24 安装可留到第 8 步做升级验证。

## 5. 生成并校验 Sparkle 更新源

在独立目录生成，避免混入旧 DMG。继续使用原有 Keychain 私钥，不导出私钥：

```sh
APPCAST_DIR="$RELEASE_OUTPUT/feed" \
DMG_PATH="$RELEASE_OUTPUT/ttcalendar-$RELEASE_VERSION.dmg" \
Scripts/update_appcast.sh

cp "$RELEASE_OUTPUT/feed/appcast.xml" docs/appcast.xml
cp "$RELEASE_OUTPUT/feed/ttcalendar-$RELEASE_VERSION.html" "docs/ttcalendar-$RELEASE_VERSION.html"
cat docs/appcast.xml
```

检查：`sparkle:version` = build，`shortVersionString` = 版本，下载地址指向该 tag 下的版本化 DMG；说明链接指向 GitHub Pages 的同名 HTML。脚本已自动设置两类地址前缀。

使用客户端公钥校验安装包签名与长度（不需要读取私钥或 Keychain）：

```sh
python3 - <<'PY'
import os, plistlib, subprocess, xml.etree.ElementTree as ET
from pathlib import Path
ns = {'s': 'http://www.andymatuschak.org/xml-namespaces/sparkle'}
item = ET.parse('docs/appcast.xml').find('./channel/item')
assert item.findtext('s:version', namespaces=ns) == os.environ['RELEASE_BUILD']
assert item.findtext('s:shortVersionString', namespaces=ns) == os.environ['RELEASE_VERSION']
enclosure = item.find('enclosure')
dmg = Path(os.environ['RELEASE_OUTPUT']) / ('ttcalendar-' + os.environ['RELEASE_VERSION'] + '.dmg')
assert int(enclosure.attrib['length']) == dmg.stat().st_size
public_key = plistlib.loads(Path('ttcalendar/Info.plist').read_bytes())['SUPublicEDKey']
subprocess.run(['swift', '-module-cache-path', '/private/tmp/ttcalendar-tests-cache', 'Scripts/verify_update.swift', str(dmg), enclosure.attrib['{' + ns['s'] + '}edSignature'], public_key], check=True)
print('PASS: build, version, size, Sparkle signature')
PY
```

## 6. 提交并推送标签，上传 Release

先用 `git diff` 审核。`git add -u` 只暂存已跟踪文件，新源码/脚本需按 `git status` 列出的路径显式添加，不要漏文件。

```sh
git diff --check
git diff --stat
git status --short
git add -u
git add "release-notes/$RELEASE_VERSION.html" "release-notes/$RELEASE_VERSION.md" "docs/ttcalendar-$RELEASE_VERSION.html"
# 在这里 git add 本次新增的源码和脚本文件；确认没有私钥、令牌或 DMG。
git diff --cached --stat
git commit -m "发布 $RELEASE_VERSION"
git tag "$RELEASE_VERSION"
git push origin "$RELEASE_VERSION"

python3 Scripts/github_cli.py release create "$RELEASE_VERSION" \
  "$RELEASE_OUTPUT/ttcalendar-$RELEASE_VERSION.dmg" "$RELEASE_OUTPUT/ttcalendar.dmg" \
  --repo akmumu/ttcalendar --verify-tag --draft \
  --title "抬头日历 $RELEASE_VERSION" --notes-file "release-notes/$RELEASE_VERSION.md"

python3 Scripts/github_cli.py release view "$RELEASE_VERSION" --repo akmumu/ttcalendar --json tagName,isDraft,assets,url
python3 Scripts/github_cli.py release edit "$RELEASE_VERSION" --repo akmumu/ttcalendar --draft=false --latest
```

这里先只推标签；main 仍保留旧 appcast。确认两个资产都上传完整后才公开 Release。

## 7. 确认下载包，然后发布客户端更新源

```sh
mkdir -p "$RELEASE_OUTPUT/download-check"
python3 Scripts/github_cli.py release download "$RELEASE_VERSION" --repo akmumu/ttcalendar \
  --pattern "ttcalendar-$RELEASE_VERSION.dmg" --dir "$RELEASE_OUTPUT/download-check"
cmp "$RELEASE_OUTPUT/ttcalendar-$RELEASE_VERSION.dmg" "$RELEASE_OUTPUT/download-check/ttcalendar-$RELEASE_VERSION.dmg"

git push origin main
python3 Scripts/github_cli.py run list --repo akmumu/ttcalendar --limit 5
```

`cmp` 无输出且成功表示上传内容一致。main 推送会触发 Pages 发布；用上一步输出的运行 ID 等待：

```sh
python3 Scripts/github_cli.py run watch 运行ID --repo akmumu/ttcalendar --exit-status
curl -fsSL https://akmumu.github.io/ttcalendar/appcast.xml
curl -fsSL "https://akmumu.github.io/ttcalendar/ttcalendar-$RELEASE_VERSION.html"
```

线上 appcast 必须出现新 build、正确地址和签名。Pages/CDN 有延迟时稍后重试，不要仅凭本地 XML 判断已发布。正常情况下无须修改 Pages 设置；应保持 `main /docs`。

## 8. 从旧版完整验证更新

在已安装旧版中点击“检查更新”，确认：

1. 能看到新版本及正确更新说明。
2. 能下载并安装，重新启动后显示新版本。
3. 原有自定义日期仍在，桌面小组件的班/休标记、月份切换正常。
4. 新增提醒可以授权、发送、修改和取消。

记录区分“签名/链接校验”“主应用升级成功”“桌面小组件验证”“实际通知送达”，不要把其中一项通过当作全部通过。

## 故障处理

| 现象 | 处理 |
| --- | --- |
| 找不到 `gh` / `create-dmg` | 回到第 0 步安装工具 |
| Git 可 push、gh 提示未登录 | 使用 `python3 Scripts/github_cli.py ...` 复用 Git 凭据，或 `gh auth login` |
| Keychain 找不到 Sparkle 密钥 | 从原电脑迁移原密钥；不要临时生成新密钥 |
| 客户端查不到新版 | 核对线上 appcast、Pages 成功状态和新 build 大于本机 build |
| 下载 404 | 核对 Release 已公开、tag 和资产文件名完全匹配 |
| 下载后签名失败 | 比较上传包与本地包；签名后是否又重新打包；是否用错密钥 |
| 更新说明 404 | 核对 `docs/ttcalendar-版本.html` 已提交，链接前缀为 GitHub Pages |
| 发布后发现问题 | 保留已发布包不变，修复后递增 build 发布下一版；必要时先恢复旧 appcast 停止继续推荐问题版 |
| 上传成功但 main push 失败 | 修复 push/合并问题后重试 main；不要再创建相同 Release |
| 小组件不刷新 | 打开主应用刷新，检查读取数据权限和重复注册；必要时移除后重新添加小组件 |
| ad-hoc 升级后日历权限变为待授权 | 在应用中重新申请日历权限；保留的缓存能展示旧数据，但不代表新数据已同步 |

1.22 轮换过 Sparkle 密钥，1.21 及更早客户端必须手动安装一次新版；1.22 及以后继续使用现有密钥可更新。恢复旧 appcast 不会自动降级已更新客户端。

## 可选：Developer ID 签名与公证

当前流程不要求付费证书。若后续改为 Developer ID：用 Xcode Archive 导出 Developer ID Application 签名 App，运行 `Scripts/notarize_app.sh` 完成公证和 stapling，再用 `STRICT_RELEASE_CHECKS=1` 和明确的 `RELEASE_DIR` 打包。不要把关闭系统安全检查作为发布步骤。

## 换电脑：迁移 Sparkle 密钥

仅换电脑时，在可信的本地目录导出并安全传输，文件绝不能提交到 Git 或上传到 Release：

```sh
"$(Scripts/find_sparkle_tool.sh generate_keys)" --account akmumu.ttcalendar -x sparkle-private-key
# 在新电脑上：
"$(Scripts/find_sparkle_tool.sh generate_keys)" --account akmumu.ttcalendar -f sparkle-private-key
```

导入后用 `-p` 核对公钥，再安全移除临时私钥文件。常规发布只读取 Keychain，不需要导出。

参考：[Sparkle 官方发布说明](https://sparkle-project.org/documentation/publishing/)。
