# Session Restore Implementation Plan

> 使用 executing-plans 在当前对话实施。保留现有改动，不提交、安装或上传。

**Goal:** 正常退出保存全部打开的便签，主动关闭移出会话。

**Architecture:** Core SessionStore 独立原子快照保存文档正文、savedText 基线、ID、URL、标题、修改日期和窗口偏好。Coordinator 在注册、编辑防抖、保存、改名、窗口变化和退出更新快照；关闭先提交排除该文档的新快照。首次无快照时导入旧 Recovery，已有快照为权威打开列表，避免旧副本复活。保留损坏快照备份并报告部分恢复错误。

**Tech Stack:** Foundation Codable/JSON、SwiftUI/AppKit、现有 DocumentStore 与窗口协调器。

## 步骤

- [x] 在 NoteWindowCoordinatorChecks 扩展 fixture 可重用目录；先写混合便签退出恢复、丢弃/取消关闭、会话写入失败、文件变化/丢失测试。运行观察旧代码失败。
- [x] 新建 Sources/StarMemoCore/Documents/SessionStore.swift：SessionDocument Codable；SessionStore.load() 返回可解码记录及恢复警告，save(_:) 原子写入。存储在 Recovery/Session/session.json；损坏文件先复制为唯一备份再允许更新。
- [x] DraftRecoveryStore 提供同目录 sessionStore；Coordinator 默认使用它。requestQuit 返回 persistSession()，不再关闭文档或逐张弹保存提示。
- [x] restoreDrafts 优先恢复会话，干净文档读磁盘，脏文档保留 savedText 与日期；缺文件转草稿提示。初始化恢复过程中禁止写入部分会话，结束后统一写入。旧草稿仅在无会话时导入。
- [x] requestClose 先写排除文档的会话再关闭，失败保留窗口。已关闭文档的异步编辑回调拒绝继续写副本。保存、改名、位置变化及防抖编辑均更新快照。
- [x] 扩展损坏/部分恢复、旧副本迁移、重复恢复、窗口位置和关闭后延迟回调检查。回归现有保存冲突和退出测试。
- [x] 运行全 Core/UI 检查，构建 0.1.8 / Build 9 本地包，更新说明、校验包内容。不覆盖旧安装包，不修改真实笔记。

## 验证命令

使用 SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.2.sdk，工程内 CLANG_MODULE_CACHE_PATH 与 SWIFTPM_MODULECACHE_OVERRIDE。

`swift run --disable-sandbox --build-system native StarMemoUIChecks session`

`swift run --disable-sandbox --build-system native StarMemoCoreChecks`

完整 UI 运行 `.build/debug/StarMemoUIChecks`（获准的临时测试窗口）。

## 自查

正常退出不写正式 Markdown 文件；不保存只丢弃修改、不删除原文件。保存失败和快照失败都不能悄悄丢内容。沿用现有屏幕边界处理，颜色等仍按全局设置。断电只能保证最近成功快照。
