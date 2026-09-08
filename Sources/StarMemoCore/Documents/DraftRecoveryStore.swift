import Foundation

public struct RecoveryDraft: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var text: String
    public var fileURL: URL?
    public var suggestedTitle: String
    public var lastKnownModificationDate: Date?
    public var updatedAt: Date

    public init(
        id: UUID,
        text: String,
        fileURL: URL?,
        suggestedTitle: String,
        lastKnownModificationDate: Date? = nil,
        updatedAt: Date
    ) {
        self.id = id
        self.text = text
        self.fileURL = fileURL
        self.suggestedTitle = suggestedTitle
        self.lastKnownModificationDate = lastKnownModificationDate
        self.updatedAt = updatedAt
    }
}

public struct DraftRecoveryStore: Sendable {
    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func save(_ draft: RecoveryDraft) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(draft)
        try data.write(to: url(for: draft.id), options: .atomic)
    }

    public func loadAll() throws -> [RecoveryDraft] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        let decoder = JSONDecoder()
        return urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(RecoveryDraft.self, from: data)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    public func remove(id: UUID) throws {
        let draftURL = url(for: id)
        guard FileManager.default.fileExists(atPath: draftURL.path) else {
            return
        }
        try FileManager.default.removeItem(at: draftURL)
    }

    private func url(for id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString).appendingPathExtension("json")
    }
}
