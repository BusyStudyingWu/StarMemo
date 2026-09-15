# StarMemo

macOS 原生 Markdown 便签应用，使用 SwiftUI、AppKit 和 MarkdownEngine。

当前版本：**0.1.9（Build 10）**。仓库目前为私有，Release 下载需要仓库访问权限。

## 下载与安装

在 [GitHub Releases](https://github.com/BusyStudyingWu/StarMemo/releases) 下载
`StarMemo-0.1.9-macOS-arm64.dmg`，打开后将 `StarMemo.app` 拖入“应用程序”。
安装包面向 Apple Silicon（M 系列芯片）及 macOS 14+；没有提供或验证 Intel 安装包。

升级前请先保存便签并退出旧版，再替换应用。0.1.7 起只保留屏幕顶部菜单栏的便签星星入口，不在 Dock 或 Command-Tab 中占位置。从“应用程序”再次打开可显示已有便签，没有便签时新建一张。

**安全提示：当前安装包未做 Developer ID 签名和 Apple 公证，可能被 Gatekeeper 阻止。**
不要关闭系统安全功能。如果无法确认安装包来源，请停止安装或自行从源码构建。
Release 同时提供 SHA-256 校验文件，用于核对下载完整性，不代表 Apple 安全认证。

## 功能

- Markdown 编辑与行内预览，支持标题、列表、任务框、代码等。
- 多便签窗口、置顶、颜色与透明度设置。
- 自动收起的标题栏：单击名字改名，拖动标题栏空白处移动窗口。
- 点击正文确认改名；改名期间仅移开鼠标不会提交。
- Markdown 文件保存、重命名、冲突处理与本地恢复副本。
- 正常退出保留打开的便签和未保存草稿，下次恢复内容及窗口位置；主动关闭的便签不再恢复。
- 顶部星星菜单提供新建、打开、设置和退出；保留原生保存确认流程。
- 设置只保留一组，修改即时应用于所有打开的便签。新建使用默认设置，重开恢复该便签上次的主题、透明度和置顶状态。
- 透明度 0% 不透明、100% 背景全透明，文字及待办框不随背景淡化。
- 未完成待办框无填色，完成后使用便签主题对应的低饱和浅填色与深色勾号。

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
本轮使用 Swift 6.4、macOS 15.2 SDK 和 SwiftPM 原生构建系统；构建脚本支持传入 `--build-system native`。默认 macOS 27 SDK 在本机缺少 SwiftUI 宏插件。指定 SDK 前请确认本机存在该路径。

## 测试

```sh
swift run StarMemoCoreChecks
swift run StarMemoUIChecks
```

UI 检查需要已登录的 macOS 图形桌面，会显示并关闭临时测试窗口。
2026-09-15 验证：核心检查 29 项、UI 检查 115 项通过，0.1.9 Release 配置构建成功。新增真实窗口恢复主题、透明度、实际置顶层级及全局更新后二次重开检查；保留会话、关闭、写入失败、文件变化和损坏记录回归。菜单栏启动配置静态检查不替代正式应用的桌面验收。
新增检查覆盖五种待办配色、三档背景透明度的实渲染像素，以及主题切换后的选区、正文和撤销保持。
设置检查覆盖原生透明度滑块动作、全局同步、重开、迁移和实际背景像素；系统减少透明度的两个分支使用注入状态验证，未改动用户系统设置。0.1.7 的实际 Dock、Command-Tab 显示及顶部菜单设置入口需安装后验收。
连续鼠标拖动手感及多显示器交互尚未完成手动验收。

## 项目结构

- `Sources/StarMemoApp`：应用入口。
- `Sources/StarMemoCore`：文档、持久化与 Markdown 基础逻辑。
- `Sources/StarMemoUI`：窗口、菜单栏与编辑器集成。
- `Tests`：核心与原生 UI 检查。
- `Vendor/swift-markdown-engine`：随项目分发的 Markdown 编辑器核心。

## 文档

- [使用指南与注意事项](docs/USAGE.md)
- [架构与技术栈](docs/ARCHITECTURE.md)
- [贡献指南](CONTRIBUTING.md)
- [安全与隐私说明](SECURITY.md)
- [更新记录](CHANGELOG.md)
- [发布与验收流程](docs/RELEASING.md)

## 许可说明

MarkdownEngine 的 MIT 许可证保存在
`ThirdPartyLicenses/swift-markdown-engine-LICENSE`，来源与修改记录见
`Vendor/swift-markdown-engine/STAR_MEMO_PROVENANCE.md`。

StarMemo 自身采用 [MIT 许可证](LICENSE)。第三方代码保留各自的版权与许可声明。
许可证的选择不改变仓库当前的私有可见性。
