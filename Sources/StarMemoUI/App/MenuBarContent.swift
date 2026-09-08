import SwiftUI

public struct MenuBarContent: View {
    @ObservedObject private var controller: AppController

    public init(controller: AppController) {
        self.controller = controller
    }

    public var body: some View {
        Button("新建便笺") { controller.newNote() }
            .keyboardShortcut("n")
        Button("打开 Markdown…") {
            Task { await controller.openDocument() }
        }
        .keyboardShortcut("o")

        Menu("最近打开") {
            if controller.recentDocuments.isEmpty {
                Text("暂无文件")
            } else {
                ForEach(controller.recentDocuments, id: \.self) { url in
                    Button(url.deletingPathExtension().lastPathComponent) {
                        controller.openRecent(url)
                    }
                }
            }
        }

        if let error = controller.lastErrorMessage {
            Divider()
            Text(error)
                .foregroundStyle(.red)
        }

        Divider()
        Button("保存当前便笺") { Task { await controller.saveCurrent() } }
            .keyboardShortcut("s")
        Button("重命名当前便笺…") { controller.renameCurrent() }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        Button("关闭当前便笺") { Task { await controller.closeCurrent() } }
            .keyboardShortcut("w")
        Button("置顶/取消置顶当前便笺") { controller.togglePinnedCurrent() }
            .keyboardShortcut("p", modifiers: [.command, .shift])
        Button("显示全部") { controller.showAll() }
        Button("隐藏全部") { controller.hideAll() }
        Divider()
        SettingsLink { Text("设置…") }
        Button("退出 StarMemo") { controller.quit() }
            .keyboardShortcut("q")
    }
}
