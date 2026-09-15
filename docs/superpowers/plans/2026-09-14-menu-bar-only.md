# Menu Bar Only Implementation Plan

> 使用 executing-plans 在当前对话实施，不派发子代理，不提交或上传。

**Goal:** 运行时不占 Dock，仅保留星星菜单。

**Architecture:** LSUIElement=true 配合启动 accessory 策略；不调整窗口、持久化和退出逻辑。

**Tech Stack:** SwiftUI、AppKit、SwiftPM。

## Task 1：配置红绿测试

- [x] 新建 Tests/StarMemoUIChecks/MenuBarOnlyChecks.swift，读取源 Info.plist，断言 LSUIElement == true；读取 StarMemoApp.swift，断言启动包含 setActivationPolicy(.accessory)，不存在 setActivationPolicy(.regular)。在 UIChecks 注册。
- [x] 用 macOS 15.2 SDK 执行 swift run --disable-sandbox --build-system native StarMemoUIChecks 'menu bar only'，确认旧配置失败。
- [x] 将 Sources/StarMemoApp/StarMemoApp.swift 的 .regular 改成 .accessory；Sources/StarMemoUI/Resources/Info.plist 的 LSUIElement 改成 true。运行专项检查确认通过。

## Task 2：回归与交付

- [x] 将重开测试中的 Dock 文案改为 application reopen；保留原测试逻辑。完整执行 Core/UI 检查，UI 在临时桌面测试窗口运行，不接触真实便签。
- [x] Info.plist 更新为 0.1.7 / Build 8；README 与使用说明说明菜单栏入口和 Command-Tab 不显示，CHANGELOG 记录本地候选。
- [x] 用 SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.2.sdk bash Scripts/build-app.sh --disable-sandbox --build-system native 构建。
- [x] mktemp 创建包目录，ditto dist/StarMemo.app 后添加 /Applications 链接；hdiutil create 生成新的 dist/StarMemo-0.1.7-macOS-arm64.dmg，校验哈希和包内 LSUIElement、版本。保留旧包。
- [x] 交付本地包，说明未签名、公证、未发布；实际 Dock 和 Command-Tab 显示仍需用户安装验收。

## 自查

无新依赖、无开关、无数据迁移。菜单已具备所有操作入口；本次不承诺系统独立主菜单。配置测试是静态回归，不能替代安装后的桌面验收。
