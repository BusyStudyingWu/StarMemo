# StarMemo

macOS 原生 Markdown 便签应用，使用 SwiftUI、AppKit 和 MarkdownEngine。

## 功能

- Markdown 编辑与行内预览，支持标题、列表、任务框、代码等。
- 多便签窗口、置顶、颜色与背景浓度设置。
- 自动收起的标题栏：单击名字改名，拖动标题栏空白处移动窗口。
- 点击正文确认改名；改名期间仅移开鼠标不会提交。
- Markdown 文件保存、重命名、冲突处理与本地恢复副本。
- 菜单栏入口和原生退出流程。

## 构建与运行

需要 macOS 14 或更新版本，以及 Swift 6.3 或更新版本的工具链。
MarkdownEngine 已包含在 `Vendor` 中，无需单独下载。

```sh
swift --version
bash Scripts/build-app.sh
open dist/StarMemo.app
```

构建输出位于 `dist/StarMemo.app`。当前构建脚本不会进行 Developer ID 签名或公证。
如本地 Command Line Tools 的默认 SDK 与 Swift 工具链不匹配，可通过 `SDKROOT` 指定兼容的 macOS SDK。

## 测试

```sh
swift run StarMemoCoreChecks
swift run StarMemoUIChecks
```

UI 检查需要已登录的 macOS 图形桌面，会显示并关闭临时测试窗口。
2026-09-08 验证：核心检查 29 项、UI 检查 90 项通过，Release 构建成功。
连续鼠标拖动手感及多显示器交互尚未完成手动验收。

## 项目结构

- `Sources/StarMemoApp`：应用入口。
- `Sources/StarMemoCore`：文档、持久化与 Markdown 基础逻辑。
- `Sources/StarMemoUI`：窗口、菜单栏与编辑器集成。
- `Tests`：核心与原生 UI 检查。
- `Vendor/swift-markdown-engine`：随项目分发的 Markdown 编辑器核心。

## 许可说明

MarkdownEngine 的 MIT 许可证保存在
`ThirdPartyLicenses/swift-markdown-engine-LICENSE`，来源与修改记录见
`Vendor/swift-markdown-engine/STAR_MEMO_PROVENANCE.md`。

StarMemo 自身暂未指定开源许可证；仓库公开不代表授予额外的使用或再分发许可。
