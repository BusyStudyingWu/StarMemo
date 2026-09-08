import AppKit
import StarMemoCore

public enum CloseDecision: Sendable {
    case save
    case discard
    case cancel
}

public enum ExternalChangeDecision: Sendable {
    case reload
    case overwrite
    case saveAs
    case cancel
}

@MainActor
public protocol DocumentDialogPresenting: AnyObject {
    func decideClose(for document: MarkdownDocument) async -> CloseDecision
    func chooseSaveURL(suggestedTitle: String) async -> URL?
    func decideExternalChange(for document: MarkdownDocument) async -> ExternalChangeDecision
    func presentError(_ error: Error)
}

@MainActor
public final class AppKitDocumentDialogPresenter: DocumentDialogPresenting {
    public init() {}

    public func decideClose(for document: MarkdownDocument) async -> CloseDecision {
        let alert = NSAlert()
        alert.messageText = "要保存“\(document.displayTitle)”吗？"
        alert.informativeText = "如果不保存，这次修改将会丢失。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "不保存")
        alert.addButton(withTitle: "取消")
        return switch alert.runModal() {
        case .alertFirstButtonReturn: .save
        case .alertSecondButtonReturn: .discard
        default: .cancel
        }
    }

    public func chooseSaveURL(suggestedTitle: String) async -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md")!]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedTitle.lowercased().hasSuffix(".md")
            ? suggestedTitle
            : "\(suggestedTitle).md"
        return panel.runModal() == .OK ? panel.url : nil
    }

    public func decideExternalChange(for document: MarkdownDocument) async -> ExternalChangeDecision {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "“\(document.displayTitle)”已在别处修改"
        alert.informativeText = "你可以重新载入磁盘版本、覆盖它，或把当前内容另存为新文件。"
        alert.addButton(withTitle: "重新载入")
        alert.addButton(withTitle: "覆盖磁盘文件")
        alert.addButton(withTitle: "另存为…")
        alert.addButton(withTitle: "取消")
        return switch alert.runModal() {
        case .alertFirstButtonReturn: .reload
        case .alertSecondButtonReturn: .overwrite
        case .alertThirdButtonReturn: .saveAs
        default: .cancel
        }
    }

    public func presentError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }
}
