import Foundation
import SwiftUI

public struct MarkdownCommands: Commands {
    public init() {}

    public var body: some Commands {
        CommandMenu("Markdown") {
            Button("粗体") { send(.bold) }
                .keyboardShortcut("b")
            Button("斜体") { send(.italic) }
                .keyboardShortcut("i")
            Button("删除线") { send(.strikethrough) }
            Button("行内代码") { send(.inlineCode) }
            Button("链接") { send(.link) }
                .keyboardShortcut("k")
        }
    }

    private func send(_ command: StarMemoMarkdownCommand) {
        NotificationCenter.default.post(
            name: StarMemoMarkdownCommandRelay.request,
            object: command
        )
    }
}
