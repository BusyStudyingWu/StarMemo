import SwiftUI

public struct StarMemoAppCommands: Commands {
    private let controller: AppController
    public init(controller: AppController) { self.controller = controller }

    public var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("新建便笺") { controller.newNote() }.keyboardShortcut("n")
            Button("打开 Markdown…") { Task { await controller.openDocument() } }.keyboardShortcut("o")
        }
        CommandGroup(replacing: .saveItem) {
            Button("保存当前便笺") { Task { await controller.saveCurrent() } }.keyboardShortcut("s")
            Button("重命名当前便笺…") { controller.renameCurrent() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
        }
        CommandMenu("便笺") {
            Button("置顶/取消置顶当前便笺") { controller.togglePinnedCurrent() }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            Button("显示全部") { controller.showAll() }
            Button("隐藏全部") { controller.hideAll() }
        }
    }
}
