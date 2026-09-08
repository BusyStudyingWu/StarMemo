import Foundation
import StarMemoCore
import StarMemoTestSupport

private final class FileFixture: @unchecked Sendable {
    let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StarMemoChecks")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }
}

private func expectDocumentStoreError(
    _ expected: DocumentStoreError,
    operation: () throws -> Void
) throws {
    do {
        try operation()
        throw CheckFailure("Expected \(expected), but operation succeeded")
    } catch let error as DocumentStoreError {
        try expect(error == expected, "Expected \(expected), got \(error)")
    }
}

let documentStoreChecks: [Check] = [
    Check("document store round trips UTF-8 markdown") {
        let fixture = try FileFixture()
        let url = fixture.directory.appendingPathComponent("中文.md")
        let store = DocumentStore()
        let modificationDate = try store.write(
            "# 标题\n你好，StarMemo。",
            to: url,
            expectedModificationDate: nil,
            allowOverwrite: false
        )
        let loaded = try store.load(from: url)
        try expect(loaded.text == "# 标题\n你好，StarMemo。")
        try expect(loaded.url == url)
        try expect(loaded.modificationDate == modificationDate)
    },
    Check("document store rejects non-markdown and invalid UTF-8") {
        let fixture = try FileFixture()
        let textURL = fixture.directory.appendingPathComponent("note.txt")
        try "hello".write(to: textURL, atomically: true, encoding: .utf8)
        try expectDocumentStoreError(.notMarkdownFile) {
            _ = try DocumentStore().load(from: textURL)
        }

        let invalidURL = fixture.directory.appendingPathComponent("invalid.md")
        try Data([0xFF, 0xFE, 0xFD]).write(to: invalidURL)
        try expectDocumentStoreError(.invalidEncoding) {
            _ = try DocumentStore().load(from: invalidURL)
        }
    },
    Check("document store refuses silent external overwrite") {
        let fixture = try FileFixture()
        let url = fixture.directory.appendingPathComponent("note.md")
        let store = DocumentStore()
        _ = try store.write("disk v1", to: url, expectedModificationDate: nil, allowOverwrite: false)
        let loaded = try store.load(from: url)
        let externalDate = (loaded.modificationDate ?? Date()).addingTimeInterval(5)
        try "disk v2".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: externalDate], ofItemAtPath: url.path)

        try expectDocumentStoreError(.externalModification) {
            _ = try store.write(
                "editor",
                to: url,
                expectedModificationDate: loaded.modificationDate,
                allowOverwrite: false
            )
        }
        _ = try store.write(
            "editor",
            to: url,
            expectedModificationDate: loaded.modificationDate,
            allowOverwrite: true
        )
        let diskText = try String(contentsOf: url, encoding: .utf8)
        try expect(diskText == "editor")
    },
    Check("document store needs explicit permission to replace an existing file") {
        let fixture = try FileFixture()
        let url = fixture.directory.appendingPathComponent("existing.md")
        try "disk".write(to: url, atomically: true, encoding: .utf8)

        try expectDocumentStoreError(.externalModification) {
            _ = try DocumentStore().write(
                "editor",
                to: url,
                expectedModificationDate: nil,
                allowOverwrite: false
            )
        }
        let diskText = try String(contentsOf: url, encoding: .utf8)
        try expect(diskText == "disk")
    },
    Check("document store renames markdown and validates title") {
        let fixture = try FileFixture()
        let original = fixture.directory.appendingPathComponent("old.md")
        try "body".write(to: original, atomically: true, encoding: .utf8)
        let store = DocumentStore()
        let renamed = try store.rename(original, to: "新标题")
        try expect(renamed.lastPathComponent == "新标题.md")
        try expect(FileManager.default.fileExists(atPath: renamed.path))

        try expectDocumentStoreError(.invalidFileName) {
            _ = try store.rename(renamed, to: "  ")
        }

        let occupied = fixture.directory.appendingPathComponent("占用.md")
        try "occupied".write(to: occupied, atomically: true, encoding: .utf8)
        try expectDocumentStoreError(.destinationExists) {
            _ = try store.rename(renamed, to: "占用")
        }
    },
]
