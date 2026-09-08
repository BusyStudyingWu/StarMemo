import Combine
import Foundation

public enum DraftProtectionStatus: Equatable, Sendable {
    case pending
    case protected
    case failed(String)
}

@MainActor
public final class MarkdownDocument: ObservableObject, Identifiable {
    public let id: UUID
    @Published public var text: String {
        didSet { if text != oldValue { draftProtection = .pending } }
    }
    @Published public private(set) var savedText: String
    @Published public private(set) var fileURL: URL?
    @Published public var suggestedTitle: String {
        didSet { if suggestedTitle != oldValue { draftProtection = .pending } }
    }
    @Published public private(set) var draftProtection: DraftProtectionStatus = .pending
    @Published public private(set) var lastKnownModificationDate: Date?

    public var isDirty: Bool {
        text != savedText
    }

    public var displayTitle: String {
        fileURL?.deletingPathExtension().lastPathComponent ?? suggestedTitle
    }

    public var storageStatusTitle: String {
        if case .failed = draftProtection, isDirty { return "恢复失败" }
        return fileURL == nil ? "未保存" : (isDirty ? "已修改" : "已保存")
    }

    public var storageStatusDetail: String {
        guard isDirty else { return fileURL?.path ?? "尚未保存为 Markdown 文件；按 ⌘S 选择保存位置。" }
        switch draftProtection {
        case .pending: return "尚未保存本次修改，正在等待更新恢复副本。按 ⌘S 保存到 Markdown 文件。"
        case .protected: return "恢复副本已更新，但尚未保存本次修改到 Markdown 文件。按 ⌘S 正式保存。"
        case .failed(let message): return "恢复副本写入失败：\(message)。请立即按 ⌘S 保存，避免异常退出时丢失修改。"
        }
    }

    public func markRecoveryProtected() { draftProtection = .protected }
    public func markRecoveryFailed(_ message: String) { draftProtection = .failed(message) }

    public init(
        id: UUID = UUID(),
        text: String = "",
        savedText: String = "",
        fileURL: URL? = nil,
        suggestedTitle: String = "未命名便笺",
        lastKnownModificationDate: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.savedText = savedText
        self.fileURL = fileURL
        self.suggestedTitle = suggestedTitle
        self.lastKnownModificationDate = lastKnownModificationDate
    }

    public func markSaved(to url: URL, modificationDate: Date?) {
        fileURL = url
        savedText = text
        lastKnownModificationDate = modificationDate
        draftProtection = .pending
    }

    public func discardChanges() {
        text = savedText
    }

    public func replace(with loaded: LoadedMarkdown) {
        text = loaded.text
        savedText = loaded.text
        fileURL = loaded.url
        lastKnownModificationDate = loaded.modificationDate
    }

    public func moveFile(to url: URL) {
        fileURL = url.standardizedFileURL
    }
}
