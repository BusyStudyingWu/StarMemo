# 0.1.7 验证记录

- 两项静态配置回归：旧实现 0 passed, 2 failed；修改后 2 passed, 0 failed。
- 核心检查：29 passed, 0 failed；原生 UI 完整回归：103 passed, 0 failed。
- Release 构建成功；Swift 6.4 / macOS 15.2 SDK / SwiftPM native。
- DMG 校验通过；只读挂载确认版本 0.1.7、Build 8、LSUIElement=true，包内二进制与构建一致；已卸载。
- SHA-256：73f4c09119988fe6663016c046cb5bfbe95dcc0b9a75aa1f75ecd3d995f57cca。
- 未启动或替换正式应用，未触碰真实便签；实际 Dock、Command-Tab 与菜单栏 SettingsLink 交互留待安装验收。
- 保留当前分支与工作目录，未提交、上传或进行 Apple 签名、公证。

日志位于 .build/verification/ 下对应 0.1.7 文件。
