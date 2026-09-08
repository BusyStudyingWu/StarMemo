import Foundation
import StarMemoCore
import StarMemoTestSupport

private final class PersistenceFixture: @unchecked Sendable {
    let directory: URL
    let defaults: UserDefaults
    private let suiteName: String

    init() throws {
        let identifier = UUID().uuidString
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StarMemoPersistenceChecks")
            .appendingPathComponent(identifier)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        suiteName = "StarMemoChecks.\(identifier)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw CheckFailure("Could not create isolated UserDefaults suite")
        }
        self.defaults = defaults
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
        defaults.removePersistentDomain(forName: suiteName)
    }
}

let persistenceStoreChecks: [Check] = [
    Check("persistence recovery draft round trips and removes") {
        let fixture = try PersistenceFixture()
        let store = DraftRecoveryStore(directory: fixture.directory)
        let older = RecoveryDraft(
            id: UUID(),
            text: "older",
            fileURL: nil,
            suggestedTitle: "旧草稿",
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let newer = RecoveryDraft(
            id: UUID(),
            text: "newer",
            fileURL: fixture.directory.appendingPathComponent("saved.md"),
            suggestedTitle: "新草稿",
            lastKnownModificationDate: Date(timeIntervalSince1970: 15),
            updatedAt: Date(timeIntervalSince1970: 20)
        )
        try store.save(older)
        try store.save(newer)
        let loaded = try store.loadAll()
        try expect(loaded == [newer, older], "Drafts should be newest first")
        try store.remove(id: newer.id)
        let remaining = try store.loadAll()
        try expect(remaining == [older])
    },
    Check("persistence recovery skips a damaged draft") {
        let fixture = try PersistenceFixture()
        let store = DraftRecoveryStore(directory: fixture.directory)
        let valid = RecoveryDraft(
            id: UUID(),
            text: "still here",
            fileURL: nil,
            suggestedTitle: "完好草稿",
            updatedAt: Date()
        )
        try store.save(valid)
        try Data("not json".utf8).write(
            to: fixture.directory.appendingPathComponent("damaged.json")
        )

        let recovered = try store.loadAll()
        try expect(recovered == [valid])
    },
    Check("persistence recent documents deduplicate and cap at ten") {
        let fixture = try PersistenceFixture()
        let store = RecentDocumentsStore(defaults: fixture.defaults)
        let urls = (0..<12).map { fixture.directory.appendingPathComponent("\($0).md") }
        for url in urls {
            store.record(url)
        }
        store.record(urls[5])
        let recent = store.all()
        try expect(recent.count == 10)
        try expect(recent.first == urls[5].standardizedFileURL)
        try expect(Set(recent).count == recent.count)
        store.remove(urls[5])
        try expect(!store.all().contains(urls[5].standardizedFileURL))
    },
    Check("persistence note preferences round trip and clamp opacity") {
        let fixture = try PersistenceFixture()
        let store = NotePreferencesStore(defaults: fixture.defaults)
        let key = NotePreferencesStore.key(
            documentID: UUID(),
            fileURL: URL(fileURLWithPath: "/tmp/note.md")
        )
        let preferences = NoteWindowPreferences(
            frame: CGRect(x: 10, y: 20, width: 360, height: 300),
            appearance: .mistBlue,
            opacity: 0.2,
            isPinned: true
        )
        store.save(preferences, for: key)
        let loaded = store.load(for: key)
        try expect(loaded?.frame == preferences.frame)
        try expect(loaded?.appearance == .mistBlue)
        try expect(loaded?.opacity == 0.65)
        try expect(loaded?.isPinned == true)
    },
]
