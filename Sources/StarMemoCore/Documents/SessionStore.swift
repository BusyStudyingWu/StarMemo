import Foundation

public struct SessionDocument: Codable, Sendable {
    public var id: UUID
    public var text: String
    public var savedText: String
    public var fileURL: URL?
    public var title: String
    public var modificationDate: Date?
    public var preferences: NoteWindowPreferences

    public init(id: UUID, text: String, savedText: String, fileURL: URL?, title: String,
                modificationDate: Date?, preferences: NoteWindowPreferences) {
        self.id = id; self.text = text; self.savedText = savedText; self.fileURL = fileURL
        self.title = title; self.modificationDate = modificationDate; self.preferences = preferences
    }
}

public struct SessionLoadResult: Sendable {
    public var documents: [SessionDocument]
    public var warning: String?
}

public struct SessionStore: Sendable {
    public let url: URL
    public init(url: URL) { self.url = url }

    public func load() throws -> SessionLoadResult? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let rows = (try? JSONSerialization.jsonObject(with: data)) as? [Any]
        var documents: [SessionDocument] = []
        var damaged = rows == nil
        for row in rows ?? [] {
            if let encoded = try? JSONSerialization.data(withJSONObject: row, options: [.fragmentsAllowed]),
               let document = try? JSONDecoder().decode(SessionDocument.self, from: encoded),
               document.preferences.frame.origin.x.isFinite,
               document.preferences.frame.origin.y.isFinite,
               document.preferences.frame.width.isFinite, document.preferences.frame.width > 0,
               document.preferences.frame.height.isFinite, document.preferences.frame.height > 0 {
                documents.append(document)
            } else { damaged = true }
        }
        if damaged {
            let backup = url.deletingLastPathComponent().appendingPathComponent("damaged-\(UUID().uuidString).json")
            // Never replace the sole damaged copy before preserving it successfully.
            try FileManager.default.copyItem(at: url, to: backup)
            return SessionLoadResult(documents: documents, warning: "部分会话无法恢复，原始记录已保留：\(backup.path)")
        }
        return SessionLoadResult(documents: documents, warning: nil)
    }

    public func save(_ documents: [SessionDocument]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(documents).write(to: url, options: .atomic)
    }
}
