import Foundation

private struct RecentDocumentRecord: Codable, Sendable {
    let url: URL
    let bookmarkData: Data?
}

public final class RecentDocumentsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let storageKey: String
    private let maximumCount: Int

    public init(
        defaults: UserDefaults = .standard,
        storageKey: String = "recentDocuments",
        maximumCount: Int = 10
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.maximumCount = maximumCount
    }

    public func record(_ url: URL) {
        let canonicalURL = url.standardizedFileURL
        var records = loadRecords().filter { $0.url.standardizedFileURL != canonicalURL }
        let bookmark = try? canonicalURL.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        records.insert(RecentDocumentRecord(url: canonicalURL, bookmarkData: bookmark), at: 0)
        saveRecords(Array(records.prefix(maximumCount)))
    }

    public func remove(_ url: URL) {
        let canonicalURL = url.standardizedFileURL
        saveRecords(loadRecords().filter { $0.url.standardizedFileURL != canonicalURL })
    }

    public func all() -> [URL] {
        loadRecords().map { record in
            guard let bookmarkData = record.bookmarkData else {
                return record.url.standardizedFileURL
            }
            var isStale = false
            return (try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withoutUI,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ))?.standardizedFileURL ?? record.url.standardizedFileURL
        }
    }

    private func loadRecords() -> [RecentDocumentRecord] {
        guard let data = defaults.data(forKey: storageKey) else {
            return []
        }
        return (try? JSONDecoder().decode([RecentDocumentRecord].self, from: data)) ?? []
    }

    private func saveRecords(_ records: [RecentDocumentRecord]) {
        guard let data = try? JSONEncoder().encode(records) else {
            return
        }
        defaults.set(data, forKey: storageKey)
    }
}
