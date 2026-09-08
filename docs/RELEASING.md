# 发布与验收流程

1. 核对 `main` 源码，将 `CFBundleShortVersionString` 和 `CFBundleVersion` 同步递增，更新 CHANGELOG。
2. 运行核心和 UI 检查，记录失败、系统诊断与未验收项目。
3. 从待发布源码运行 `bash Scripts/build-app.sh`，检查应用包内版本、最低系统版本与二进制架构。
4. 使用临时打包目录放入 `StarMemo.app` 和指向 `/Applications` 的链接；使用 `hdiutil create -format UDZO` 生成 DMG。
5. 执行 `hdiutil verify`，挂载后核对包内版本和二进制，检查结束后卸载镜像。
6. 生成 `shasum -a 256` 校验文件。保留已有安装包，不覆盖不同内容的同名发布资产。
7. 提交文档和版本更改，推送后以确切提交创建 `v版本号` 标签及 Release，附加 DMG、校验文件和注意事项。
8. 重新查询 Release 的标签提交、附件名称与仓库可见性。必要时下载附件比对 SHA-256。

当前未配置自动签名、公证和自动发布。Apple Silicon 安装包不应标成 Universal。
UI 检查需要桌面会话；没有经过验证的图形环境时，不把无头 CI 的通过状态当成完整 UI 验收。
