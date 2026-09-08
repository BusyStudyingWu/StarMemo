# StarMemo 0.1.2（Build 3）

适用平台：macOS 14+，Apple Silicon（M 系列芯片）。本安装包不是 Intel / Universal 构建。

## 本次更新

- 单击标题名字改名，标题栏其他空白区域用于拖动窗口。
- 改名后点击正文确认并收起；改名期间只移开鼠标不会提交。
- 完整的 AppKit UI 测试事件循环，覆盖单击标题及正文交互。
- 补齐 README、使用注意事项、架构与技术栈、贡献指南、安全说明、发布流程和 MIT 许可证。

## 安装与升级

下载 `StarMemo-0.1.2-macOS-arm64.dmg`，打开后将应用拖入“应用程序”。
升级前保存便签并退出旧版本，不要同时运行多份应用。
启动后从屏幕顶部菜单栏的便签星星图标进入。

仓库保持私有，下载需要仓库访问权限。
安装包没有 Developer ID 签名或 Apple 公证，可能被系统阻止；不要关闭系统安全功能。
无法确认来源时请停止安装或从源码构建。

在安装包与校验文件同一目录执行：

```sh
shasum -a 256 -c SHA256SUMS.txt
```

SHA-256 用于核对下载完整性，不代表 Apple 安全认证。

## 验证与限制

- 使用 Swift 6.3.3、macOS 15.4 SDK 构建；Release 二进制为 arm64。
- 核心检查 29/29，UI 检查 90/90，Release 构建成功；DMG 镜像校验通过。
- UI 测试期间出现 macOS 输入法 `IMKCFRunLoopWakeUpReliable` 系统诊断，但所有测试完成并通过。
- 多显示器、连续鼠标拖动手感、Intel 设备以及不同 macOS 版本尚未完成全面人工验收。
- 恢复副本不能代替正式保存或备份；目前没有自动更新功能。

应用包同时保留 StarMemo MIT 许可证及 MarkdownEngine 第三方 MIT 许可证。
