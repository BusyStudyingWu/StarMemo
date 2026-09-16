# 架构与技术栈

StarMemo 使用 Swift 6、SwiftUI、AppKit 和 Swift Package Manager，最低运行系统为 macOS 14。构建工具链要求 Swift 6.3+。

## 模块边界

```text
StarMemoApp → StarMemoUI → StarMemoCore
             └────────→ MarkdownEngine（Vendor）
StarMemoApp ───────────→ StarMemoCore
```

| 目录 | 职责 |
| --- | --- |
| `Sources/StarMemoApp` | 启动、应用生命周期与菜单栏入口 |
| `Sources/StarMemoCore` | 文档状态、文件读写、会话恢复和偏好模型 |
| `Sources/StarMemoUI` | 原生窗口、设置、标题栏与编辑器集成 |
| `Vendor/swift-markdown-engine` | Markdown 解析、文本布局和行内预览 |
| `Tests` | 核心检查、AppKit UI 检查及共享测试工具 |
| `Scripts` | 应用包构建 |
| `docs/superpowers` | 历史设计与验证记录，不代表当前使用说明 |

Core 不依赖 UI 或 MarkdownEngine；界面状态通过 Combine 和 SwiftUI 绑定更新。

## 窗口与设置

`StarMemoApp` 使用 accessory 激活策略和 `MenuBarExtra`，不显示运行中的 Dock 图标。
`AppController` 连接菜单、设置和窗口管理。

`NoteWindowCoordinator` 管理文档与窗口集合、保存/关闭决策及会话恢复。
`NoteWindowController` 管理单张便签的 AppKit 面板和 SwiftUI 内容。
标题栏仅在空白区域触发窗口拖动，名称区域用于改名。

恢复窗口时先应用该便签保存的外观；全局设置订阅跳过首次值，后续用户修改对应选项时再统一应用。字号为全局设置。
背景独立使用 `1 - backgroundTransparency`，不降低文字和控件的透明度。

## 编辑与保存

`MarkdownDocument` 保存正文及已保存基线。
生产编辑路径为：

```text
NoteWindowView → StarMemoMarkdownEditor → MarkdownEngine.NativeTextViewWrapper
                         ↕ 文本绑定
                   MarkdownDocument
```

`MarkdownEditorFocusBridge` 协调正文点击、失焦和输入法组合状态。
主题、字号及编辑命令在现有编辑器上更新，避免重建导致选区或撤销历史丢失。

- `DocumentStore`：正式 Markdown 文件的读取、保存、改名和外部修改检查。
- `SessionStore`：未关闭便签的正文、保存基线、路径、标题与窗口偏好；采用原子写入。
- `DraftRecoveryStore`：恢复副本及旧草稿兼容。
- `UserDefaults`：全局设置、窗口偏好与最近文件记录。

正常退出保存会话；主动关闭单张便签走保存／不保存／取消流程。会话不是正式文件备份，也没有应用层加密。

## 旧实现与测试

`MarkdownEditorView`、`MarkdownTextView`、`MarkdownPreviewView` 及 Core 中的旧 Markdown 解析/预览代码仍保留在项目中，但不属于当前便签正文的主编辑路径。
修改现行编辑行为应从 `StarMemoMarkdownEditor` 和 Vendor 引擎入手；测试中的 `legacy:` 检查不能替代生产路径验收。

核心检查覆盖存储、冲突、恢复及基础 Markdown 逻辑；UI 检查覆盖真实编辑器、焦点、窗口和设置。
自动检查不能替代中文输入法、多显示器拖动、不同系统版本及辅助功能的人工验收。
