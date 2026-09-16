# 贡献指南

欢迎提交问题和改进建议。开始较大改动前，建议先开 Issue 说明目标。

## 本地开发

需要 macOS 14+、Swift 6.3+ 和兼容的 macOS SDK。依赖的 MarkdownEngine 源码已内置。

```sh
swift build
swift run StarMemoCoreChecks
swift run StarMemoUIChecks
bash Scripts/build-app.sh
```

UI 检查需要已登录的图形桌面，会显示临时窗口。不要使用自己的重要便签测试丢弃或覆盖操作。

如果工具链与默认 SDK 不匹配，可通过 `SDKROOT` 指向本机实际安装的兼容 SDK。历史验证使用过 Swift 6.4 与 macOS 15.2 SDK，并传入 `--build-system native`；这是特定环境的兼容方案，不是所有开发者的必需配置。构建脚本接受 SwiftPM 参数。

## 提交修改

- 使用独立分支，一次解决一个问题，并说明测试结果和未覆盖项。
- 修复问题先补复现检查；编辑器改动需检查中文输入法、撤销/重做及失焦重进。
- 当前编辑器入口是 `StarMemoMarkdownEditor`；旧实现与模块边界见[架构文档](docs/ARCHITECTURE.md)。
- 行为变化同步更新使用文档和 CHANGELOG。
- 不提交构建产物、凭据、真实便签、恢复记录或个人绝对路径。
- 修改 Vendor 时保留许可证，并更新[来源与修改记录](Vendor/swift-markdown-engine/STAR_MEMO_PROVENANCE.md)。

## 报告问题

请提供 macOS 版本、芯片类型、应用版本、复现步骤及预期／实际行为。示例 Markdown 和截图应去除私人内容。

安全问题不要公开利用细节，反馈方式见 [SECURITY.md](SECURITY.md)。
