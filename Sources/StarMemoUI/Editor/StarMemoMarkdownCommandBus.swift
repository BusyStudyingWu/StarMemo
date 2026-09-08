import Foundation
import MarkdownEngine

public enum StarMemoMarkdownCommand: Hashable, Sendable {
    case bold
    case italic
    case strikethrough
    case inlineCode
    case link
}

@MainActor
public final class StarMemoMarkdownCommandBus {
    public let engineBus: MarkdownEditorBus
    private let names: [StarMemoMarkdownCommand: Notification.Name]

    public init(documentID: UUID) {
        let prefix = "StarMemo.Markdown.\(documentID.uuidString)"
        let names: [StarMemoMarkdownCommand: Notification.Name] = [
            .bold: .init("\(prefix).bold"),
            .italic: .init("\(prefix).italic"),
            .strikethrough: .init("\(prefix).strikethrough"),
            .inlineCode: .init("\(prefix).inlineCode"),
            .link: .init("\(prefix).link"),
        ]
        self.names = names
        engineBus = MarkdownEditorBus(
            applyBoldRequest: names[.bold],
            applyItalicRequest: names[.italic],
            applyStrikethroughRequest: names[.strikethrough],
            applyInlineCodeRequest: names[.inlineCode],
            applyLinkRequest: names[.link]
        )
    }

    public func post(_ command: StarMemoMarkdownCommand) {
        guard let name = names[command] else { return }
        NotificationCenter.default.post(name: name, object: nil)
    }
}
