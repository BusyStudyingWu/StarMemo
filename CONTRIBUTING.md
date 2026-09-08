# 贡献指南

仓库目前为私有，只有获授权的协作者能提交 Issue 或 Pull Request。

## 本地开发

需要 macOS 14+、Swift 6.3+ 工具链。先执行 `swift --version` 确认版本。

```sh
swift build
swift run StarMemoCoreChecks
swift run StarMemoUIChecks
bash Scripts/build-app.sh
```

UI 测试会显示临时窗口，需在已登录的图形桌面运行；不要直接在自己的重要便签上测试丢弃或冲突覆盖。

## 提交修改

- 使用独立分支，保持修改范围清晰。
- 修复问题时先补复现测试；涉及编辑器时测试中文输入法、撤销/重做和失焦重进。
- 说明测试命令、结果和未覆盖项，不把旧实现检查当成新编辑器的验收证据。
- 更新行为对应的使用文档与 CHANGELOG。
- 不提交 `.build`、`dist`、凭据、便签、恢复记录或个人路径。
- 修改 Vendor 源码时同步更新来源与修改记录，保留第三方许可证。

## 报告问题

请提供 macOS 版本、芯片类型、应用版本、最小复现步骤、预期行为和实际行为。
截图或示例 Markdown 应先去除私人内容。安全问题请遵循 [SECURITY.md](SECURITY.md)。
