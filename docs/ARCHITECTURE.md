# 架构与技术栈

## 技术栈

| 层次 | 技术 | 作用 |
| --- | --- | --- |
| 平台 | macOS 14+ | 原生窗口、菜单栏、文件面板 |
| 语言与构建 | Swift 6 模式、Swift Package Manager；工具链 6.3+ | 模块构建与依赖管理 |
| 界面 | SwiftUI | 菜单、设置、标题栏和状态绑定 |
| 原生交互 | AppKit / NSTextView / NSPanel | 文本输入、窗口拖动、焦点及系统对话框 |
| 状态 | Combine / ObservableObject | 文档和界面状态更新 |
| Markdown | 内置 MarkdownEngine 源码快照 | Markdown 文本编辑、标记隐藏与渲染 |
| 持久化 | Foundation 文件 API、恢复记录、UserDefaults | Markdown 文件、恢复副本、最近文件与偏好 |

## 模块关系

```text
StarMemoApp
└── StarMemoUI
    ├── StarMemoCore
    └── MarkdownEngine（Vendor 内置）

StarMemoCoreChecks / StarMemoUIChecks
└── StarMemoTestSupport
```

`StarMemoApp` 启动应用。`AppController` 连接菜单、设置和文档窗口管理。
`NoteWindowCoordinator` 管理打开的文档、窗口、保存/关闭决策和恢复任务。
每个 `NoteWindowController` 持有一个原生面板，并挂载 SwiftUI 界面。

## 编辑数据流

`MarkdownDocument` 是 Markdown 正文的唯一业务数据源。
`StarMemoMarkdownEditor` 将文档绑定到 MarkdownEngine；原生文本变化经绑定回写文档。
`MarkdownEditorFocusBridge` 协调正文点击、失焦和输入法组合状态，避免标题操作误触正文编辑。
主题和字号变更在现有编辑器上更新，保留选区、滚动与撤销历史。

标题栏的布局锚点标记名字和按钮范围；`TitleBarDragRegion` 仅对空白区域调用系统窗口拖动。
重命名和保存由协调器交给文档存储服务，不由标题组件直接操作文件。

## 存储与边界

`DocumentStore` 负责读取、保存、重命名和外部修改检查。
`DraftRecoveryStore` 保存恢复副本；它不替代用户选择路径后的正式保存。
窗口偏好和最近文件记录与正文文件分开保存。

`StarMemoCore/Markdown` 中保留早期解析与预览逻辑；当前生产编辑路径使用 MarkdownEngine。
UI 测试中的 `legacy:` 前缀区分早期实现检查，不能用这些检查单独证明生产编辑器行为正确。

## 测试边界

核心测试覆盖存储、冲突及 Markdown 基础逻辑；UI 测试覆盖原生编辑器、焦点、标题栏和窗口协调。
UI 测试运行完整 AppKit 事件循环，需要图形桌面。
自动测试并不替代多显示器、连续拖动手感、不同系统版本及辅助功能的人工验收。
