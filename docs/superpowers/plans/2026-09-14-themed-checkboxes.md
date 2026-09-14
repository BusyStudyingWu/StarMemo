# Themed Checkboxes Implementation Plan

> **For agentic workers:** Use executing-plans in the current conversation, as selected by the user. No subagent dispatch.

**Goal:** 未完成框无填色，已完成框使用便签主题对应的低饱和浅填色和深色勾号。

**Architecture:** MarkdownEditorTheme 新增已完成填色与勾号颜色，默认保留引擎历史配色。StarMemo 的 NoteColorPalette 提供五套覆盖值，现有主题更新路径触发原生重绘。不改尺寸、圆角、点击、保存和撤销逻辑。

**Tech Stack:** Swift / AppKit / SwiftUI / 内置 MarkdownEngine，无新依赖。

## Global Constraints

- 根目录 `/Users/busy/Documents/Codex/2026-09-08/new-chat/StarMemo-release`；保留当前修复分支，不提交或上传。
- 未完成填色 `.clear`，现有正文色 0.62 alpha 描边及 1.5 点宽度保持。
- 已完成填色本身为浅色且 alpha 为 1，独立于便签背景透明度；勾号 sRGB `(0.22, 0.25, 0.27)`。
- 已完成填色 sRGB：纸白 `(0.87,0.87,0.85)`；雾蓝 `(0.77,0.84,0.88)`；薰衣草 `(0.84,0.80,0.89)`；暖黄 `(0.89,0.84,0.68)`；石墨 `(0.72,0.74,0.76)`。
- 只使用临时测试窗口和合成文本，不启动正式应用或修改真实便签。

## Task 1: 颜色配置与绘制接线

Files: `Sources/StarMemoUI/Windows/NoteColorPalette.swift`、`Sources/StarMemoUI/Editor/StarMemoMarkdownThemeFactory.swift`、`Vendor/swift-markdown-engine/Sources/MarkdownEngine/Configuration/MarkdownEditorTheme.swift`、`Vendor/swift-markdown-engine/Sources/MarkdownEngine/Renderer/MarkdownTextLayoutFragment.swift`、`Tests/StarMemoUIChecks/StarMemoMarkdownConfigurationChecks.swift`。

- [x] 先把未完成填色测试改为 `try expect(theme.taskCheckboxUncheckedFill.alphaComponent == 0)`，运行观察旧代码失败。
- [x] 增加新配置断言：`taskCheckboxCheckedFill` 等于对应主题值，`taskCheckboxCheckmark` 与浅填色对比度至少 4.5；默认主题仍等于历史薄荷绿及深色勾号。
- [x] 引擎主题新增两个 NSColor 属性及带默认值的初始化参数：

```swift
taskCheckboxCheckedFill: NSColor = NSColor(calibratedRed: 0.69, green: 0.93, blue: 0.81, alpha: 1),
taskCheckboxCheckmark: NSColor = NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.08, alpha: 1)
```

- [x] 在初始化器保存参数；渲染器用 `configuration.theme.taskCheckboxCheckedFill.setFill()` 和 `configuration.theme.taskCheckboxCheckmark.setStroke()` 替换硬编码值，保留其余绘制语句。
- [x] NoteColorPalette 提供 `checkedTaskFill` 与 `taskCheckmark`，按上述全局约束构造 NSColor；工厂设置 `.clear` 未完成填色及这两个完成态颜色。
- [x] 运行配置检查，确认通过。

## Task 2: 实际渲染与行为回归

Files: 新建 `Tests/StarMemoUIChecks/ThemedCheckboxChecks.swift`，在 `Tests/StarMemoUIChecks/UIChecks.swift` 注册。

- [x] 同一生产 NoteWindowController 放入 `- [ ] 未完成\n- [x] 已完成`，逐个调用 `setAppearance` 并截图到 `.build/verification/checkboxes-0.1.6/`。
- [x] 在实际截图中统计与完成填色相符的像素，证明渲染器使用主题配置而非仅对象值改变；在透明背景下检查未完成框内部无填色。先在旧渲染路径运行使之失败，再接线。
- [x] 比较 0%、50%、100% 背景透明度下的完成框像素，确保固定填色；保存五套主题截图并逐张查看。
- [x] 比较主题切换前后 NSTextView 身份、选区、正文和撤销能力；复用既有原生任务框勾选与 Markdown 回写检查。

## Task 3: 验收与本地交付

- [x] 更新 `Vendor/swift-markdown-engine/STAR_MEMO_PROVENANCE.md`、CHANGELOG、README；Info.plist 版本 0.1.6 / Build 7。
- [x] 使用本机 macOS 15.2 SDK：`SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.2.sdk swift run --disable-sandbox --build-system native StarMemoUIChecks` 编译；完整原生鼠标测试在获准的正常桌面权限下执行 `.build/debug/StarMemoUIChecks`。
- [x] 运行同参数 `StarMemoCoreChecks`，再用 `bash Scripts/build-app.sh --disable-sandbox --build-system native` 构建，确认日志退出码并执行 `git diff --check`。
- [x] 在新的 mktemp staging 目录用 ditto 复制 app，放入 `/Applications` 链接；`hdiutil create -format UDZO` 生成 `dist/StarMemo-0.1.6-macOS-arm64.dmg`，不覆盖旧包。
- [x] `hdiutil verify`、SHA-256 和只读挂载比对包内版本、二进制、许可证；完成后卸载。交付本地文件，不发布 Release。

## 自查

规格中五主题、未完成透明、完成态低饱和、深色勾号、背景独立、动态更新与原行为均对应上述任务。任务 1 与 2 交替执行红绿测试，避免配置正确但渲染仍硬编码。已采用用户选定的当前对话执行方式。
