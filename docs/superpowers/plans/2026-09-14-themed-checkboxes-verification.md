# 0.1.6 待办框验证记录

- 红灯：旧实现下，未完成无填色和完成态主题像素检查均失败。
- 绿灯：9 项待办专项检查通过；五主题分别验证背景 alpha 0、0.5、1，共 15 张真实编辑器截图。
- 核心检查：29 passed, 0 failed。
- UI 首轮：100 passed, 1 failed；失败项为空白区点击后的文末光标检查。
- UI 完整复跑：101 passed, 0 failed。未改动点击逻辑，焦点检查的偶发失败仍需关注。
- Release 配置构建成功；使用 Swift 6.4、macOS 15.2 SDK、SwiftPM native 构建系统。
- 已检查五主题截图；未完成空心、完成浅填色与深色勾号，背景透明度不淡化完成框。
- DMG 校验通过；只读挂载核对版本 0.1.6 / Build 7、arm64 二进制及两份许可证与构建源一致。
- 挂载后首次卸载提示忙，重试已成功弹出；未安装或启动正式应用。
- SHA-256：d9672c27ec6c680ca122f1f1b70e073f3a0d4cee17116b173434388c9ae19ad8。
- 保留当前分支与工作目录，不提交、不上传 Release；未做 Apple Developer ID 签名或公证。

测试日志和截图位于本地 .build/verification/，安装包位于 dist/StarMemo-0.1.6-macOS-arm64.dmg。
