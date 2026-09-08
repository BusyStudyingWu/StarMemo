import Foundation

public struct LoadedMarkdown: Equatable, Sendable {
    public let text: String
    public let url: URL
    public let modificationDate: Date?

    public init(text: String, url: URL, modificationDate: Date?) {
        self.text = text
        self.url = url
        self.modificationDate = modificationDate
    }
}

public enum DocumentStoreError: Error, Equatable, Sendable {
    case notMarkdownFile
    case invalidEncoding
    case externalModification
    case invalidFileName
    case destinationExists
    case fileAlreadyOpen
}

extension DocumentStoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notMarkdownFile:
            "请选择扩展名为 .md 的 Markdown 文件。"
        case .invalidEncoding:
            "文件不是有效的 UTF-8 文本。"
        case .externalModification:
            "文件已被其他应用修改。"
        case .invalidFileName:
            "文件名为空或包含无效字符。"
        case .destinationExists:
            "同名 Markdown 文件已经存在。"
        case .fileAlreadyOpen:
            "这个文件已由另一张便笺打开。请切换到那张便笺编辑，或选择其他文件名保存。"
        }
    }
}

public struct DocumentStore: Sendable {
    public init() {}

    public func load(from url: URL) throws -> LoadedMarkdown {
        guard url.pathExtension.lowercased() == "md" else {
            throw DocumentStoreError.notMarkdownFile
        }

        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw DocumentStoreError.invalidEncoding
        }

        return LoadedMarkdown(
            text: text,
            url: url.standardizedFileURL,
            modificationDate: try modificationDate(for: url)
        )
    }

    @discardableResult
    public func write(
        _ text: String,
        to url: URL,
        expectedModificationDate: Date?,
        allowOverwrite: Bool
    ) throws -> Date? {
        guard url.pathExtension.lowercased() == "md" else {
            throw DocumentStoreError.notMarkdownFile
        }

        if !allowOverwrite {
            let fileExists = FileManager.default.fileExists(atPath: url.path)
            if let expectedModificationDate {
                guard fileExists else {
                    throw DocumentStoreError.externalModification
                }
                let currentModificationDate = try modificationDate(for: url)
                guard currentModificationDate == expectedModificationDate else {
                    throw DocumentStoreError.externalModification
                }
            } else if fileExists {
                throw DocumentStoreError.externalModification
            }
        }

        try Data(text.utf8).write(to: url, options: .atomic)
        return try modificationDate(for: url)
    }

    public func rename(_ url: URL, to title: String) throws -> URL {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var baseName = trimmedTitle
        if baseName.lowercased().hasSuffix(".md") {
            baseName.removeLast(3)
        }

        let invalidCharacters = CharacterSet(charactersIn: "/:").union(.newlines)
        guard !baseName.isEmpty,
              baseName != ".",
              baseName != "..",
              baseName.rangeOfCharacter(from: invalidCharacters) == nil
        else {
            throw DocumentStoreError.invalidFileName
        }

        let destination = url.deletingLastPathComponent()
            .appendingPathComponent(baseName)
            .appendingPathExtension("md")
            .standardizedFileURL
        let source = url.standardizedFileURL

        guard destination != source else {
            return source
        }
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw DocumentStoreError.destinationExists
        }

        try FileManager.default.moveItem(at: source, to: destination)
        return destination
    }

    private func modificationDate(for url: URL) throws -> Date? {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.modificationDate] as? Date
    }
}
