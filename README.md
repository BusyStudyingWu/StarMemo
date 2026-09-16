# StarMemo

把 Markdown 写在桌面上。

StarMemo 是一款 macOS 原生便签应用，适合随手记录、待办清单和工作备忘。常驻菜单栏，不占 Dock。

[下载安装](https://github.com/BusyStudyingWu/StarMemo/releases) · [使用指南](docs/USAGE.md) · [AtomGit 镜像](https://atomgit.com/collectstar/StarMemo)

## 主要功能

- **边写边预览**：支持标题、列表、待办、引用和代码等 Markdown 格式，编辑时显示语法标记。
- **桌面便签**：多窗口、置顶、主题颜色和背景透明度；文字与控件保持清晰。
- **继续上次工作**：正常退出后，再次启动恢复未关闭的便签及其位置、主题和置顶状态。
- **本地 Markdown 文件**：打开、保存和重命名 `.md` 文件，检测外部修改冲突。

## 安装与使用

需要 **macOS 14+、Apple Silicon（M 系列芯片）**。安装包在 [GitHub Releases](https://github.com/BusyStudyingWu/StarMemo/releases) 提供；AtomGit 镜像中的版本标签不代表已附带安装包。

1. 下载 DMG，将 `StarMemo.app` 拖入“应用程序”。
2. 启动后，点击屏幕顶部的便签星星图标，新建或打开便签。
3. 鼠标移到便签上沿：点击名字改名，拖动空白处移动窗口。
4. 使用 `⌘S` 保存文件。正常退出会保留会话；关闭单张便签后不再自动恢复。

**注意：安装包未做 Apple Developer ID 签名和公证。** 无法确认来源时不要绕过系统安全提示。会话恢复不等于备份，重要内容请另存并备份。更多限制见[使用指南](docs/USAGE.md)。

## 开发

使用 Swift 6.3+ 和兼容的 macOS SDK，基于 SwiftUI、AppKit 与 Swift Package Manager。MarkdownEngine 已内置，无需另行下载。

```sh
bash Scripts/build-app.sh
swift run StarMemoCoreChecks
swift run StarMemoUIChecks
```

应用输出到 `dist/StarMemo.app`。UI 检查需要已登录的 macOS 图形桌面，会显示临时测试窗口。构建环境说明见[贡献指南](CONTRIBUTING.md)。

## 项目文档

- [架构与技术栈](docs/ARCHITECTURE.md)
- [贡献指南](CONTRIBUTING.md)
- [安全与隐私](SECURITY.md)
- [更新记录](CHANGELOG.md)
- [发布流程](docs/RELEASING.md)

## 许可与致谢

StarMemo 采用 [MIT 许可证](LICENSE)。

Markdown 编辑器基于随附的 MarkdownEngine 源码快照，来自 [NotchNotes](https://github.com/oil-oil/NotchNotes) 项目。保留其 [MIT 许可证](ThirdPartyLicenses/swift-markdown-engine-LICENSE)，来源及本地修改见[记录](Vendor/swift-markdown-engine/STAR_MEMO_PROVENANCE.md)。
