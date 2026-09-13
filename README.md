# StarMemo

macOS 原生 Markdown 便签应用，使用 SwiftUI、AppKit 和 MarkdownEngine。

当前版本：**0.1.5（Build 6）**。仓库目前为私有，Release 下载需要仓库访问权限。

## 下载与安装

在 [GitHub Releases](https://github.com/BusyStudyingWu/StarMemo/releases) 下载
`StarMemo-0.1.5-macOS-arm64.dmg`，打开后将 `StarMemo.app` 拖入“应用程序”。
安装包面向 Apple Silicon（M 系列芯片）及 macOS 14+；没有提供或验证 Intel 安装包。

升级前请先保存便签并退出旧版，再替换应用。0.1.4 起同时提供 Dock 和屏幕顶部菜单栏的便签星星入口；点击 Dock 显示已有便签，没有便签时新建一张。

**安全提示：当前安装包未做 Developer ID 签名和 Apple 公证，可能被 Gatekeeper 阻止。**
不要关闭系统安全功能。如果无法确认安装包来源，请停止安装或自行从源码构建。
Release 同时提供 SHA-256 校验文件，用于核对下载完整性，不代表 Apple 安全认证。

## 功能

- Markdown 编辑与行内预览，支持标题、列表、任务框、代码等。
- 多便签窗口、置顶、颜色与透明度设置。
- 自动收起的标题栏：单击名字改名，拖动标题栏空白处移动窗口。
- 点击正文确认改名；改名期间仅移开鼠标不会提交。
- Markdown 文件保存、重命名、冲突处理与本地恢复副本。
- Dock、应用主菜单、菜单栏入口和原生退出流程。
- 设置只保留一组，颜色、透明度、字号、置顶即时应用于所有便签，新建与重开也沿用。
- 透明度 0% 不透明、100% 背景全透明，文字及待办框不随背景淡化。

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
2026-09-13 验证：核心检查 29 项、UI 检查 98 项通过，Release 构建成功。
设置检查覆盖原生透明度滑块动作、全局同步、重开、迁移和实际背景像素；系统减少透明度的两个分支使用注入状态验证，未改动用户系统设置。正式应用的系统主菜单切换仍需实机验收。
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
