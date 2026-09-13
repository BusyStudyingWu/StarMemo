# Global Transparency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for inline execution, or superpowers:subagent-driven-development only if the user chooses delegation. Track steps with checkboxes.

**Goal:** 设置只保留一组，真实背景透明度与显示值一致，所有便签即时更新并在重开后沿用。

**Architecture:** AppSettings 保存统一设置，协调器为窗口提供同一实例。窗口复用现有字号订阅方式响应颜色、透明度和置顶；新建时全局外观优先，单张偏好只提供窗口位置。背景使用独立组件，与正文和控件分层。

**Tech Stack:** Swift 6.3、SwiftUI、AppKit、Combine、现有 Swift Package 测试程序；不增加依赖。

## Global Constraints

- 规格：`docs/superpowers/specs/2026-09-11-global-transparency-design.md`。
- “透明度”0%–100%，背景 alpha = 1 - 透明度，不限制到旧的 82% 不透明底色。
- 文字、待办框、操作控件不受背景 alpha 影响。
- 系统减少透明度覆盖视觉效果，但不覆盖保存的用户值。
- 保留已有未提交修改；不创建提交、不启动正式应用、不安装、不上传 Release。只允许隔离的临时测试窗口。
- 工作根目录：`/Users/busy/Documents/Codex/2026-09-08/new-chat/StarMemo-release`。以下路径均相对于该目录。

## Task 1: 统一设置与一次性迁移

**Files:** `Sources/StarMemoUI/App/AppController.swift`、`Sources/StarMemoCore/Preferences/NotePreferences.swift`、`Sources/StarMemoUI/Windows/NoteWindowView.swift`、`Tests/StarMemoUIChecks/AppControllerChecks.swift`、`Tests/StarMemoCoreChecks/PersistenceStoreChecks.swift`。

**Interfaces:** 新增 `AppSettings.backgroundTransparency: Double`，范围 0...1；`windowOpacity` 如保留兼容访问，则只返回 `1 - backgroundTransparency`。`NoteWindowPreferences.opacity` 与 `NoteWindowState.opacity` 保留为真实背景 alpha，范围改为 0...1。

- [ ] 添加旧数据迁移、重复初始化、新值持久化和上下限测试。关键断言：

```swift
defaults.set(0.65, forKey: "windowOpacity")
let settings = AppSettings(defaults: defaults)
try expect(abs(settings.backgroundTransparency - 0.18) < 0.000001)
settings.backgroundTransparency = 0.5
try expect(AppSettings(defaults: defaults).backgroundTransparency == 0.5)
```

- [ ] 运行 `env SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk swift run StarMemoUIChecks 'app settings'`，确认新 API 缺失或行为不符导致失败。
- [ ] 在新存储键不存在时一次性读取旧值；新键存在时直接读取，不重新换算。迁移计算：

```swift
let oldOpacity = min(max(defaults.object(forKey: "windowOpacity") == nil
    ? 0.94 : defaults.double(forKey: "windowOpacity"), 0.65), 1)
let migrated = 1 - (0.82 + (oldOpacity - 0.65) / 0.35 * 0.18)
```

- [ ] 用 `min(max(value, 0), 1)` 归一化真实 alpha；修改旧测试中 0.65 下限预期，保留非法输入测试。
- [ ] 重跑对应 UI 和 Core 检查，验证迁移只执行一次、0 和 1 正确保留。

## Task 2: 全局广播与精简设置页

**Files:** `Sources/StarMemoUI/Windows/NoteWindowController.swift`、`Sources/StarMemoUI/App/SettingsView.swift`、`Sources/StarMemoApp/StarMemoApp.swift`、`Tests/StarMemoUIChecks/CurrentNoteSettingsChecks.swift`；协调器只做必要的共享设置接线调整。

**Interfaces:** 复用 `setAppearance(_:)`、`setOpacity(_:)`、`togglePinned()`。窗口持有 `Set<AnyCancellable>`，弱引用订阅，避免窗口关闭后泄漏。不用合并订阅覆盖无关选项。

- [ ] 将“当前与新建隔离”测试替换为全局同步测试：两张真实临时便签、修改设置、再新建、关闭重开；断言状态、NSWindow 外观和 level、持久化值、Markdown 正文未变。示例：

```swift
settings.defaultAppearance = .graphite
settings.backgroundTransparency = 0.5
settings.defaultPinned = true
try expect(firstWindow.state.appearance == .graphite)
try expect(secondWindow.state.opacity == 0.5)
try expect(secondWindow.window?.level == .floating)
```

- [ ] 运行 `swift run StarMemoUIChecks 'global settings'`，观察旧窗口未同步的失败。
- [ ] 窗口完成初始化后建立订阅，包括首次值发送，使旧单张外观不覆盖全局设置。订阅模式：

```swift
settings.$backgroundTransparency.sink { [weak self] value in
    self?.setOpacity(1 - min(max(value, 0), 1))
}.store(in: &settingsObservers)
settings.$defaultAppearance.sink { [weak self] value in
    self?.setAppearance(value)
}.store(in: &settingsObservers)
settings.$defaultPinned.sink { [weak self] value in
    guard let self, self.state.isPinned != value else { return }
    self.togglePinned()
}.store(in: &settingsObservers)
```

- [ ] 设置页去掉 `CurrentNoteControls` 和 selection 依赖，保留颜色 Picker、透明度 Slider、字号 Slider、置顶 Toggle。一组说明“立即应用于所有便签，新建便签也沿用”。透明度控件使用：

```swift
Slider(value: $settings.backgroundTransparency, in: 0...1, step: 0.01)
    .disabled(reduceTransparency)
Text("\(Int((settings.backgroundTransparency * 100).rounded()))%")
if reduceTransparency {
    Text("系统已开启减少透明度，背景暂时保持不透明")
}
```

- [ ] 使用 `@Environment(\.accessibilityReduceTransparency)`；移除不再使用的最近便签设置追踪代码前，检索全部引用，更新对应测试。保留标题栏单张快捷操作。
- [ ] 重跑全局设置测试，并测试单张图钉不会影响其他便签，后续全局置顶再次覆盖所有窗口。

## Task 3: 真实背景图层与视觉证据

**Files:** 新建 `Sources/StarMemoUI/Windows/NoteBackgroundView.swift`；修改 `NoteWindowView.swift`、`NoteColorPalette.swift`、`Tests/StarMemoUIChecks/StarMemoMarkdownConfigurationChecks.swift`、`Tests/StarMemoUIChecks/NoteWindowChecks.swift`。

**Interfaces:** `NoteBackgroundView(appearance: NoteAppearance, opacity: Double)`；由环境读取减少透明度。透明度影响背景子树，不影响包含编辑器的父 ZStack。

- [ ] 先添加线性 alpha 测试：`surfaceOpacity(for: 0) == 0`、`surfaceOpacity(for: 0.5) == 0.5`、`surfaceOpacity(for: 1) == 1`，观察旧换算失败。
- [ ] `surfaceOpacity` 仅归一化 0...1，移除对比度下限。将原先极端底色的强制对比度测试限定在不透明背景；另外检查所有透明度下 ink 和 checkbox stroke 的 alpha 为 1。
- [ ] 将背景层移入独立组件，颜色与磨砂一同淡化；0% 透明时为不透明底色，100% 透明时不存在残余磨砂底板。缩放背景 alpha 的代码必须位于背景组件，不允许放到整个窗口或编辑器父容器。
- [ ] 用临时 NSWindow 在不同底色上显示生产组件，分别生成 0%、50%、100% 透明度截图，比较背景像素并确认正文与任务框不淡化。使用 `.environment(\.accessibilityReduceTransparency, true)` 和 false 检查组件覆盖与恢复；不改变用户系统设置。
- [ ] 截图保存 `.build/verification/transparency-0.1.5-*.png` 并逐张查看。若原生磨砂无法被离屏截图准确捕获，记录限制，不能仅凭状态断言宣称视觉通过。

## Task 4: 回归、版本与本地安装包

**Files:** `Sources/StarMemoUI/Resources/Info.plist`、`README.md`、`CHANGELOG.md`、`docs/USAGE.md`、`docs/ARCHITECTURE.md`。

- [ ] 版本递增为 0.1.5 / Build 6；文档删除过时的“当前便签 / 默认值”说明，记录透明度方向、升级和辅助功能规则。
- [ ] 使用 SDKROOT 运行 `swift run StarMemoCoreChecks`、`swift run StarMemoUIChecks`，输出存入 `.build/verification/*-0.1.5.log`，读取失败详情并逐项处理。
- [ ] 执行 `bash Scripts/build-app.sh`、`git diff --check`；确认退出码和实际通过数量。
- [ ] 采用新的 staging 目录与新的 DMG 文件名，不覆盖旧版：

```sh
set -e
starmemo_stage=$(mktemp -d .build/package-0.1.5.XXXXXX)
ditto dist/StarMemo.app "$starmemo_stage/StarMemo.app"
ln -s /Applications "$starmemo_stage/Applications"
hdiutil create -volname 'StarMemo 0.1.5' -srcfolder "$starmemo_stage" -format UDZO dist/StarMemo-0.1.5-macOS-arm64.dmg
hdiutil verify dist/StarMemo-0.1.5-macOS-arm64.dmg
shasum -a256 dist/StarMemo-0.1.5-macOS-arm64.dmg
```

- [ ] 只读挂载核对包内版本和二进制，卸载。交付本地安装包、真实测试结果和未覆盖的实机项；不上传。

## 计划自查

已覆盖规格的真实透明度、全局同步、旧值迁移、重开、单张快捷操作、系统覆盖及恢复、文字独立渲染和本地交付。

## 执行记录（2026-09-13）

- [x] 全局设置、一次性迁移与窗口订阅；关闭窗口取消订阅。
- [x] 精简设置页，原生滑块动作及系统覆盖分支验证。
- [x] 移除独立磨砂底板，使用单一背景层；真实像素验证 0%、50%、100%，文字保持可见。无需依赖跨窗口磨砂合成。
- [x] 新测试在旧实现上失败，修复后通过；98 项 UI、29 项核心检查全部通过，Release 构建成功。
- [x] 沙盒内三项鼠标检查失败，旧代码对照同样失败；正常桌面权限下三项及完整套件均通过。
- [x] 本地 DMG 创建与只读挂载核验，包内版本为 0.1.5 / Build 6，二进制及许可证与构建输出一致。

工具链实际使用本机 macOS 15.2 SDK（原计划 15.4 已不存在）、Swift 6.4 与原生构建系统。系统辅助功能分支通过显式依赖注入验证，未操作用户系统设置。未安装正式应用、未提交、未上传。
