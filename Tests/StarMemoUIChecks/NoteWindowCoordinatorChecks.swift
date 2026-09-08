import Foundation
import StarMemoCore
import StarMemoTestSupport
import StarMemoUI

@MainActor
private final class FakeDialogPresenter: DocumentDialogPresenting {
    var closeDecisions: [CloseDecision] = []
    var closeDecisionsByDocumentID: [UUID: CloseDecision] = [:]
    var externalDecisions: [ExternalChangeDecision] = []
    var saveURLs: [URL?] = []
    var errors: [String] = []

    func decideClose(for document: MarkdownDocument) async -> CloseDecision {
        if let decision = closeDecisionsByDocumentID[document.id] {
            return decision
        }
        return closeDecisions.isEmpty ? .cancel : closeDecisions.removeFirst()
    }

    func chooseSaveURL(suggestedTitle: String) async -> URL? {
        saveURLs.isEmpty ? nil : saveURLs.removeFirst()
    }

    func decideExternalChange(for document: MarkdownDocument) async -> ExternalChangeDecision {
        externalDecisions.isEmpty ? .cancel : externalDecisions.removeFirst()
    }

    func presentError(_ error: Error) {
        errors.append(error.localizedDescription)
    }
}

@MainActor
private final class FakeNoteWindow: NoteWindowHandling {
    let documentID: UUID
    var isKeyWindow = false
    private(set) var showCount = 0
    private(set) var hideCount = 0
    private(set) var closeCount = 0
    private(set) var togglePinnedCount = 0
    private(set) var renameCount = 0
    var onActivate: (() -> Void)?
    var onRename: ((String) -> Void)?

    init(documentID: UUID) {
        self.documentID = documentID
    }

    func showAndActivate() { showCount += 1 }
    func hide() { hideCount += 1 }
    func closeImmediately() { closeCount += 1 }
    func togglePinned() { togglePinnedCount += 1 }
    func beginRenaming() { renameCount += 1 }
    func simulateActivation() { onActivate?() }
    func simulateRename(_ title: String) { onRename?(title) }
}

@MainActor
private final class WindowRecorder {
    var windows: [UUID: FakeNoteWindow] = [:]

    func make(
        document: MarkdownDocument,
        preferences: NoteWindowPreferences,
        onCloseRequest: @escaping (UUID) -> Void,
        onRename: @escaping (UUID, String) -> Void,
        onPreferencesChange: @escaping (UUID, NoteWindowPreferences) -> Void,
        onActivate: @escaping (UUID) -> Void
    ) -> any NoteWindowHandling {
        let window = FakeNoteWindow(documentID: document.id)
        window.onActivate = { onActivate(document.id) }
        window.onRename = { onRename(document.id, $0) }
        windows[document.id] = window
        return window
    }
}

@MainActor
private func coordinatorFixture() -> (
    NoteWindowCoordinator,
    FakeDialogPresenter,
    WindowRecorder,
    URL
) {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("StarMemoCoordinatorChecks")
        .appendingPathComponent(UUID().uuidString)
    try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let defaults = UserDefaults(suiteName: "StarMemoCoordinatorChecks.\(UUID().uuidString)")!
    let dialogs = FakeDialogPresenter()
    let recorder = WindowRecorder()
    let coordinator = NoteWindowCoordinator(
        documentStore: DocumentStore(),
        recoveryStore: DraftRecoveryStore(directory: root.appendingPathComponent("Recovery")),
        recentDocumentsStore: RecentDocumentsStore(defaults: defaults),
        preferencesStore: NotePreferencesStore(defaults: defaults),
        dialogs: dialogs,
        windowFactory: recorder.make
    )
    return (coordinator, dialogs, recorder, root)
}

@MainActor
let noteWindowCoordinatorChecks: [Check] = [
    Check("restoring historical duplicate drafts detaches the second copy without losing text") {
        let (coordinator, _, _, root) = coordinatorFixture()
        let url = root.appendingPathComponent("shared.md")
        try "disk".write(to: url, atomically: true, encoding: .utf8)
        let ids = [UUID(), UUID()]
        let store = DraftRecoveryStore(directory: root.appendingPathComponent("Recovery"))
        for (index, id) in ids.enumerated() {
            try store.save(RecoveryDraft(id: id, text: "draft \(index)", fileURL: url, suggestedTitle: "shared", updatedAt: Date().addingTimeInterval(Double(index))))
        }
        try coordinator.restoreDrafts()
        let documents = ids.compactMap { coordinator.document(id: $0) }
        try expect(documents.count == 2)
        try expect(documents.filter { $0.fileURL != nil }.count == 1)
        try expect(Set(documents.map(\.text)) == Set(["draft 0", "draft 1"]))
        let disk = try String(contentsOf: url, encoding: .utf8)
        try expect(disk == "disk")
    },
    Check("failed recovery exposes an honest document status without losing text") {
        let (coordinator, _, _, root) = coordinatorFixture()
        try Data("not a directory".utf8).write(to: root.appendingPathComponent("Recovery"))
        let document = coordinator.newDocument(text: "keep this text")
        coordinator.flushRecoveryDrafts()
        try expect(document.storageStatusTitle == "恢复失败")
        try expect(document.text == "keep this text" && document.isDirty)
        try expect(document.storageStatusDetail.contains("⌘S"))
    },
    Check("rename and close commands target the active note") {
        let (coordinator, dialogs, recorder, _) = coordinatorFixture()
        let first = coordinator.newDocument(text: "first")
        let second = coordinator.newDocument(text: "second")
        recorder.windows[first.id]?.simulateActivation()
        coordinator.commandRenameCurrent()
        try expect(recorder.windows[first.id]?.renameCount == 1)
        try expect(recorder.windows[second.id]?.renameCount == 0)
        dialogs.closeDecisions = [.cancel]
        await coordinator.commandCloseCurrent()
        try expect(coordinator.openDocumentCount == 2)
        dialogs.closeDecisions = [.discard]
        await coordinator.commandCloseCurrent()
        try expect(coordinator.document(id: first.id) == nil)
        try expect(coordinator.document(id: second.id) != nil)
    },
    Check("saving rejects a target already owned by another open note") {
        let (coordinator, dialogs, _, root) = coordinatorFixture()
        let url = root.appendingPathComponent("owned.md")
        try "original".write(to: url, atomically: true, encoding: .utf8)
        let first = try coordinator.openDocument(at: url)
        let second = coordinator.newDocument(text: "second")
        dialogs.saveURLs = [url]
        let saved = await coordinator.saveDocument(second.id)
        try expect(!saved)
        try expect(second.fileURL == nil && second.isDirty)
        let diskText = try String(contentsOf: url, encoding: .utf8)
        let reopened = try coordinator.openDocument(at: url)
        try expect(diskText == "original")
        try expect(reopened.id == first.id)
        try expect(dialogs.errors.count == 1)
    },
    Check("unsaved rename immediately refreshes recovery title") {
        let (coordinator, _, recorder, root) = coordinatorFixture()
        let document = coordinator.newDocument(text: "body", suggestedTitle: "old")
        coordinator.flushRecoveryDrafts()
        recorder.windows[document.id]?.simulateRename("new")
        let draft = try require(DraftRecoveryStore(directory: root.appendingPathComponent("Recovery")).loadAll().first)
        try expect(draft.suggestedTitle == "new")
    },
    Check("saving rejects a symbolic link to an open note") {
        let (coordinator, dialogs, _, root) = coordinatorFixture()
        let url = root.appendingPathComponent("owner.md")
        let alias = root.appendingPathComponent("alias.md")
        try "original".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: url)
        let first = try coordinator.openDocument(at: url)
        let second = coordinator.newDocument(text: "second")
        dialogs.saveURLs = [alias]
        let saved = await coordinator.saveDocument(second.id)
        let diskText = try String(contentsOf: url, encoding: .utf8)
        let reopened = try coordinator.openDocument(at: alias)
        try expect(!saved && diskText == "original")
        try expect(reopened.id == first.id && second.fileURL == nil)
    },
    Check("conflict save-as rejects another open note without changing either document") {
        let (coordinator, dialogs, _, root) = coordinatorFixture()
        let source = root.appendingPathComponent("source.md")
        let target = root.appendingPathComponent("target.md")
        try "source".write(to: source, atomically: true, encoding: .utf8)
        try "target".write(to: target, atomically: true, encoding: .utf8)
        let first = try coordinator.openDocument(at: source)
        let second = try coordinator.openDocument(at: target)
        first.text = "editing source"
        second.text = "editing target"
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(20)], ofItemAtPath: source.path)
        dialogs.externalDecisions = [.saveAs]
        dialogs.saveURLs = [target]
        let saved = await coordinator.saveDocument(first.id)
        let disk = try String(contentsOf: target, encoding: .utf8)
        try expect(!saved && disk == "target")
        try expect(first.fileURL == source && first.text == "editing source" && first.isDirty)
        try expect(second.fileURL == target && second.text == "editing target" && second.isDirty)
        try expect(dialogs.errors.count == 1)
    },
    Check("coordinator closes clean notes without prompting") {
        let (coordinator, dialogs, recorder, _) = coordinatorFixture()
        let document = coordinator.newDocument()

        let didClose = await coordinator.requestClose(document.id)
        try expect(didClose)
        try expect(dialogs.closeDecisions.isEmpty)
        try expect(recorder.windows[document.id]?.closeCount == 1)
        try expect(coordinator.openDocumentCount == 0)
    },
    Check("coordinator removes stale recovery when a note becomes clean") {
        let (coordinator, _, _, root) = coordinatorFixture()
        let document = coordinator.newDocument()
        document.text = "短暂修改"
        coordinator.flushRecoveryDrafts()
        document.text = ""

        let didClose = await coordinator.requestClose(document.id)
        let drafts = try DraftRecoveryStore(
            directory: root.appendingPathComponent("Recovery")
        ).loadAll()
        try expect(didClose)
        try expect(drafts.isEmpty)
    },
    Check("coordinator saves a new dirty note before closing") {
        let (coordinator, dialogs, recorder, root) = coordinatorFixture()
        let destination = root.appendingPathComponent("第一次保存.md")
        let document = coordinator.newDocument()
        document.text = "# 留住我"
        dialogs.closeDecisions = [.save]
        dialogs.saveURLs = [destination]

        let didClose = await coordinator.requestClose(document.id)
        let savedText = try String(contentsOf: destination, encoding: .utf8)
        try expect(didClose)
        try expect(savedText == "# 留住我")
        try expect(recorder.windows[document.id]?.closeCount == 1)
    },
    Check("first save migrates window preferences to the file key") {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PreferenceMigration.\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let defaults = UserDefaults(suiteName: "PreferenceMigration.\(UUID().uuidString)")!
        let preferencesStore = NotePreferencesStore(defaults: defaults)
        let dialogs = FakeDialogPresenter()
        let recorder = WindowRecorder()
        let coordinator = NoteWindowCoordinator(
            documentStore: DocumentStore(),
            recoveryStore: DraftRecoveryStore(directory: root.appendingPathComponent("Recovery")),
            recentDocumentsStore: RecentDocumentsStore(defaults: defaults),
            preferencesStore: preferencesStore,
            dialogs: dialogs,
            windowFactory: recorder.make
        )
        let document = coordinator.newDocument()
        document.text = "内容"
        let destination = root.appendingPathComponent("保存后.md")
        let oldKey = NotePreferencesStore.key(documentID: document.id, fileURL: nil)
        let preferences = NoteWindowPreferences(
            frame: CGRect(x: 1, y: 2, width: 333, height: 444),
            appearance: .lavender,
            opacity: 0.8,
            isPinned: true
        )
        preferencesStore.save(preferences, for: oldKey)
        dialogs.saveURLs = [destination]

        let didSave = await coordinator.saveDocument(document.id)
        let newKey = NotePreferencesStore.key(documentID: document.id, fileURL: destination)
        try expect(didSave)
        try expect(preferencesStore.load(for: oldKey) == nil)
        try expect(preferencesStore.load(for: newKey) == preferences)
    },
    Check("coordinator cancel keeps dirty note open") {
        let (coordinator, dialogs, recorder, _) = coordinatorFixture()
        let document = coordinator.newDocument()
        document.text = "还没想好"
        dialogs.closeDecisions = [.cancel]

        let didClose = await coordinator.requestClose(document.id)
        try expect(!didClose)
        try expect(recorder.windows[document.id]?.closeCount == 0)
        try expect(coordinator.openDocumentCount == 1)
    },
    Check("coordinator keeps a note open when first save fails") {
        let (coordinator, dialogs, recorder, root) = coordinatorFixture()
        let document = coordinator.newDocument()
        document.text = "不能丢"
        dialogs.closeDecisions = [.save]
        dialogs.saveURLs = [root.appendingPathComponent("missing/note.md")]

        let didClose = await coordinator.requestClose(document.id)

        try expect(!didClose)
        try expect(coordinator.openDocumentCount == 1)
        try expect(recorder.windows[document.id]?.closeCount == 0)
        try expect(dialogs.errors.count == 1)
    },
    Check("coordinator opens one window per file") {
        let (coordinator, _, recorder, root) = coordinatorFixture()
        let url = root.appendingPathComponent("唯一.md")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "正文".write(to: url, atomically: true, encoding: .utf8)

        let first = try coordinator.openDocument(at: url)
        let second = try coordinator.openDocument(at: url)

        try expect(first.id == second.id)
        try expect(coordinator.openDocumentCount == 1)
        try expect(recorder.windows[first.id]?.showCount == 2)
    },
    Check("coordinator resolves symbolic links before deduplicating files") {
        let (coordinator, _, _, root) = coordinatorFixture()
        let originalURL = root.appendingPathComponent("原文件.md")
        let linkURL = root.appendingPathComponent("链接.md")
        try "正文".write(to: originalURL, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: originalURL)

        let original = try coordinator.openDocument(at: originalURL)
        let linked = try coordinator.openDocument(at: linkURL)

        try expect(original.id == linked.id)
        try expect(coordinator.openDocumentCount == 1)
    },
    Check("external conflict cancel preserves editor text") {
        let (coordinator, dialogs, recorder, root) = coordinatorFixture()
        let url = root.appendingPathComponent("冲突.md")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "磁盘一".write(to: url, atomically: true, encoding: .utf8)
        let document = try coordinator.openDocument(at: url)
        document.text = "编辑器版本"
        try "磁盘二，长度不同".write(to: url, atomically: true, encoding: .utf8)
        dialogs.closeDecisions = [.save]
        dialogs.externalDecisions = [.cancel]

        let didClose = await coordinator.requestClose(document.id)
        try expect(!didClose)
        try expect(document.text == "编辑器版本")
        try expect(recorder.windows[document.id]?.closeCount == 0)
    },
    Check("external conflict reload adopts the disk version") {
        let (coordinator, dialogs, _, root) = coordinatorFixture()
        let url = root.appendingPathComponent("载入冲突.md")
        try "磁盘一".write(to: url, atomically: true, encoding: .utf8)
        let document = try coordinator.openDocument(at: url)
        document.text = "编辑器版本"
        let changedDate = (document.lastKnownModificationDate ?? Date()).addingTimeInterval(10)
        try "外部版本".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: changedDate], ofItemAtPath: url.path)
        dialogs.externalDecisions = [.reload]

        let didSave = await coordinator.saveDocument(document.id)
        try expect(didSave)
        try expect(document.text == "外部版本")
        try expect(!document.isDirty)
    },
    Check("external conflict overwrite keeps the editor version") {
        let (coordinator, dialogs, _, root) = coordinatorFixture()
        let url = root.appendingPathComponent("覆盖冲突.md")
        try "磁盘一".write(to: url, atomically: true, encoding: .utf8)
        let document = try coordinator.openDocument(at: url)
        document.text = "编辑器版本"
        let changedDate = (document.lastKnownModificationDate ?? Date()).addingTimeInterval(10)
        try "外部版本".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: changedDate], ofItemAtPath: url.path)
        dialogs.externalDecisions = [.overwrite]

        let didSave = await coordinator.saveDocument(document.id)
        let diskText = try String(contentsOf: url, encoding: .utf8)
        try expect(didSave)
        try expect(diskText == "编辑器版本")
    },
    Check("external conflict save-as preserves both files") {
        let (coordinator, dialogs, _, root) = coordinatorFixture()
        let originalURL = root.appendingPathComponent("原冲突.md")
        let newURL = root.appendingPathComponent("另存版本.md")
        try "磁盘一".write(to: originalURL, atomically: true, encoding: .utf8)
        let document = try coordinator.openDocument(at: originalURL)
        document.text = "编辑器版本"
        let changedDate = (document.lastKnownModificationDate ?? Date()).addingTimeInterval(10)
        try "外部版本".write(to: originalURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: changedDate], ofItemAtPath: originalURL.path)
        dialogs.externalDecisions = [.saveAs]
        dialogs.saveURLs = [newURL]

        let didSave = await coordinator.saveDocument(document.id)
        let originalText = try String(contentsOf: originalURL, encoding: .utf8)
        let newText = try String(contentsOf: newURL, encoding: .utf8)
        try expect(didSave)
        try expect(originalText == "外部版本")
        try expect(newText == "编辑器版本")
        try expect(document.fileURL == newURL.standardizedFileURL)
    },
    Check("restored saved draft keeps its file baseline") {
        let (originalCoordinator, _, _, root) = coordinatorFixture()
        let url = root.appendingPathComponent("恢复.md")
        try "磁盘原文".write(to: url, atomically: true, encoding: .utf8)
        let originalDocument = try originalCoordinator.openDocument(at: url)
        originalDocument.text = "恢复后的编辑"
        originalCoordinator.flushRecoveryDrafts()

        let dialogs = FakeDialogPresenter()
        dialogs.closeDecisions = [.save]
        let recorder = WindowRecorder()
        let defaults = UserDefaults(suiteName: "RecoveredCoordinator.\(UUID().uuidString)")!
        let restoredCoordinator = NoteWindowCoordinator(
            documentStore: DocumentStore(),
            recoveryStore: DraftRecoveryStore(directory: root.appendingPathComponent("Recovery")),
            recentDocumentsStore: RecentDocumentsStore(defaults: defaults),
            preferencesStore: NotePreferencesStore(defaults: defaults),
            dialogs: dialogs,
            windowFactory: recorder.make
        )
        try restoredCoordinator.restoreDrafts()
        let restored = try require(restoredCoordinator.document(id: originalDocument.id))

        let didClose = await restoredCoordinator.requestClose(restored.id)
        let diskText = try String(contentsOf: url, encoding: .utf8)
        try expect(didClose)
        try expect(diskText == "恢复后的编辑")
        try expect(dialogs.externalDecisions.isEmpty)
    },
    Check("rename conflict leaves the original file attached") {
        let (coordinator, dialogs, recorder, root) = coordinatorFixture()
        let originalURL = root.appendingPathComponent("原名.md")
        let occupiedURL = root.appendingPathComponent("占用.md")
        try "原文".write(to: originalURL, atomically: true, encoding: .utf8)
        try "占用".write(to: occupiedURL, atomically: true, encoding: .utf8)
        let document = try coordinator.openDocument(at: originalURL)

        recorder.windows[document.id]?.simulateRename("占用")

        try expect(document.fileURL == originalURL.standardizedFileURL)
        try expect(FileManager.default.fileExists(atPath: originalURL.path))
        try expect(dialogs.errors.count == 1)
    },
    Check("coordinator hides and shows every note") {
        let (coordinator, _, recorder, _) = coordinatorFixture()
        let first = coordinator.newDocument()
        let second = coordinator.newDocument()

        coordinator.hideAll()
        coordinator.showAll()

        try expect(recorder.windows[first.id]?.hideCount == 1)
        try expect(recorder.windows[second.id]?.hideCount == 1)
        try expect(recorder.windows[first.id]?.showCount == 2)
        try expect(recorder.windows[second.id]?.showCount == 2)
    },
    Check("coordinator targets the most recently activated note") {
        let (coordinator, _, recorder, _) = coordinatorFixture()
        let first = coordinator.newDocument()
        let second = coordinator.newDocument()
        recorder.windows[first.id]?.simulateActivation()

        coordinator.togglePinnedCurrentDocument()

        try expect(recorder.windows[first.id]?.togglePinnedCount == 1)
        try expect(recorder.windows[second.id]?.togglePinnedCount == 0)
    },
    Check("cancelled quit does not partially close other notes") {
        let (coordinator, dialogs, recorder, root) = coordinatorFixture()
        let first = coordinator.newDocument()
        let second = coordinator.newDocument()
        first.text = "第一张"
        second.text = "第二张"
        coordinator.flushRecoveryDrafts()
        dialogs.closeDecisions = [.discard, .cancel]

        let didQuit = await coordinator.requestQuit()
        let drafts = try DraftRecoveryStore(
            directory: root.appendingPathComponent("Recovery")
        ).loadAll()
        try expect(!didQuit)
        try expect(coordinator.openDocumentCount == 2)
        try expect(recorder.windows[first.id]?.closeCount == 0)
        try expect(recorder.windows[second.id]?.closeCount == 0)
        try expect(Set(drafts.map(\.id)) == Set([first.id, second.id]))
    },
]
