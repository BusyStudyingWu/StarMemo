import Combine
import CoreGraphics
import Foundation
import StarMemoCore

public extension Notification.Name {
    static let starMemoRecoveryError = Notification.Name("StarMemoRecoveryError")
}

public typealias NoteWindowFactory = @MainActor (
    _ document: MarkdownDocument,
    _ preferences: NoteWindowPreferences,
    _ onCloseRequest: @escaping (UUID) -> Void,
    _ onRename: @escaping (UUID, String) -> Void,
    _ onPreferencesChange: @escaping (UUID, NoteWindowPreferences) -> Void,
    _ onActivate: @escaping (UUID) -> Void
) -> any NoteWindowHandling

@MainActor
public final class NoteWindowCoordinator {
    private let documentStore: DocumentStore
    private let recoveryStore: DraftRecoveryStore
    private let recentDocumentsStore: RecentDocumentsStore
    private let preferencesStore: NotePreferencesStore
    private let dialogs: any DocumentDialogPresenting
    private let windowFactory: NoteWindowFactory
    private let defaultPreferencesProvider: @MainActor () -> NoteWindowPreferences

    private var documents: [UUID: MarkdownDocument] = [:]
    private var windows: [UUID: any NoteWindowHandling] = [:]
    private var documentIDsByURL: [URL: UUID] = [:]
    private var textObservers: [UUID: AnyCancellable] = [:]
    private var recoveryTasks: [UUID: Task<Void, Never>] = [:]
    private var lastActiveDocumentID: UUID?

    public var openDocumentCount: Int { documents.count }

    public init(
        documentStore: DocumentStore,
        recoveryStore: DraftRecoveryStore,
        recentDocumentsStore: RecentDocumentsStore,
        preferencesStore: NotePreferencesStore,
        dialogs: any DocumentDialogPresenting,
        defaultPreferencesProvider: @escaping @MainActor () -> NoteWindowPreferences = {
            NoteWindowCoordinator.fallbackPreferences
        },
        windowFactory: @escaping NoteWindowFactory
    ) {
        self.documentStore = documentStore
        self.recoveryStore = recoveryStore
        self.recentDocumentsStore = recentDocumentsStore
        self.preferencesStore = preferencesStore
        self.dialogs = dialogs
        self.defaultPreferencesProvider = defaultPreferencesProvider
        self.windowFactory = windowFactory
    }

    public convenience init(
        recoveryDirectory: URL,
        dialogs: any DocumentDialogPresenting = AppKitDocumentDialogPresenter(),
        settings: AppSettings? = nil
    ) {
        self.init(
            documentStore: DocumentStore(),
            recoveryStore: DraftRecoveryStore(directory: recoveryDirectory),
            recentDocumentsStore: RecentDocumentsStore(),
            preferencesStore: NotePreferencesStore(),
            dialogs: dialogs,
            defaultPreferencesProvider: {
                NoteWindowPreferences(
                    frame: Self.fallbackPreferences.frame,
                    appearance: settings?.defaultAppearance ?? .clear,
                    opacity: settings?.windowOpacity ?? 0.94,
                    isPinned: settings?.defaultPinned ?? false
                )
            },
            windowFactory: { document, preferences, onClose, onRename, onPreferences, onActivate in
                NoteWindowController(
                    document: document,
                    preferences: preferences,
                    fontSize: CGFloat(settings?.editorFontSize ?? 15),
                    settings: settings,
                    onCloseRequest: onClose,
                    onRename: onRename,
                    onPreferencesChange: onPreferences,
                    onActivate: onActivate
                )
            }
        )
    }

    @discardableResult
    public func newDocument(
        text: String = "",
        suggestedTitle: String = "未命名便笺"
    ) -> MarkdownDocument {
        let document = MarkdownDocument(text: text, suggestedTitle: suggestedTitle)
        register(document)
        return document
    }

    @discardableResult
    public func openDocument(at url: URL) throws -> MarkdownDocument {
        let canonicalURL = canonicalFileURL(url)
        if let id = documentIDsByURL[canonicalURL],
           let document = documents[id] {
            windows[id]?.showAndActivate()
            return document
        }

        let loaded = try documentStore.load(from: canonicalURL)
        let document = MarkdownDocument(
            text: loaded.text,
            savedText: loaded.text,
            fileURL: loaded.url,
            suggestedTitle: loaded.url.deletingPathExtension().lastPathComponent,
            lastKnownModificationDate: loaded.modificationDate
        )
        register(document)
        recentDocumentsStore.record(canonicalURL)
        return document
    }

    public func document(id: UUID) -> MarkdownDocument? {
        documents[id]
    }

    @discardableResult
    public func requestClose(_ id: UUID) async -> Bool {
        guard let document = documents[id] else { return true }
        guard document.isDirty else {
            close(document)
            return true
        }

        switch await dialogs.decideClose(for: document) {
        case .save:
            guard await save(document) else { return false }
            close(document)
            return true
        case .discard:
            try? recoveryStore.remove(id: document.id)
            close(document)
            return true
        case .cancel:
            return false
        }
    }

    @discardableResult
    public func saveDocument(_ id: UUID) async -> Bool {
        guard let document = documents[id] else { return false }
        return await save(document)
    }

    public func requestQuit() async -> Bool {
        flushRecoveryDrafts()
        var documentsToClose: [MarkdownDocument] = []
        for document in Array(documents.values) {
            if !document.isDirty {
                documentsToClose.append(document)
                continue
            }
            switch await dialogs.decideClose(for: document) {
            case .save:
                guard await save(document) else { return false }
                documentsToClose.append(document)
            case .discard:
                documentsToClose.append(document)
            case .cancel:
                return false
            }
        }
        documentsToClose.forEach(close)
        return true
    }

    public func showAll() {
        windows.values.forEach { $0.showAndActivate() }
    }

    public func hideAll() {
        windows.values.forEach { $0.hide() }
    }

    public func saveCurrentDocument() async {
        guard let id = currentDocumentID() else { return }
        _ = await saveDocument(id)
    }

    public func togglePinnedCurrentDocument() {
        guard let id = currentDocumentID() else { return }
        windows[id]?.togglePinned()
    }

    public var recentDocumentURLs: [URL] {
        recentDocumentsStore.all()
    }

    public func restoreDrafts() throws {
        for draft in try recoveryStore.loadAll() where documents[draft.id] == nil {
            let document: MarkdownDocument
            if let url = draft.fileURL,
               documentIDsByURL[canonicalFileURL(url)] == nil,
               let loaded = try? documentStore.load(from: url) {
                document = MarkdownDocument(
                    id: draft.id,
                    text: draft.text,
                    savedText: loaded.text,
                    fileURL: loaded.url,
                    suggestedTitle: draft.suggestedTitle,
                    lastKnownModificationDate: draft.lastKnownModificationDate
                        ?? loaded.modificationDate
                )
            } else {
                document = MarkdownDocument(
                    id: draft.id,
                    text: draft.text,
                    savedText: "",
                    fileURL: nil,
                    suggestedTitle: draft.suggestedTitle
                )
            }
            register(document)
            if document.isDirty { document.markRecoveryProtected() }
        }
    }

    public func flushRecoveryDrafts() {
        for document in documents.values where document.isDirty {
            saveRecovery(for: document)
        }
    }

    private func register(_ document: MarkdownDocument) {
        documents[document.id] = document
        if let url = document.fileURL.map(canonicalFileURL) {
            documentIDsByURL[url] = document.id
        }
        let preferencesKey = NotePreferencesStore.key(
            documentID: document.id,
            fileURL: document.fileURL
        )
        let preferences = preferencesStore.load(for: preferencesKey) ?? defaultPreferencesProvider()
        let window = windowFactory(
            document,
            preferences,
            { [weak self] id in
                Task { @MainActor in _ = await self?.requestClose(id) }
            },
            { [weak self] id, title in self?.rename(id: id, to: title) },
            { [weak self] id, preferences in self?.store(preferences, for: id) },
            { [weak self] id in self?.markActive(id) }
        )
        windows[document.id] = window
        lastActiveDocumentID = document.id
        observeTextChanges(in: document)
        window.showAndActivate()
    }

    private func observeTextChanges(in document: MarkdownDocument) {
        textObservers[document.id] = document.$text.dropFirst().sink { [weak self, weak document] _ in
            Task { @MainActor in
                guard let self, let document else { return }
                self.scheduleRecovery(for: document)
            }
        }
    }

    private func scheduleRecovery(for document: MarkdownDocument) {
        recoveryTasks[document.id]?.cancel()
        recoveryTasks[document.id] = Task { @MainActor [weak self, weak document] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, let self, let document else { return }
            self.saveRecovery(for: document)
        }
    }

    private func saveRecovery(for document: MarkdownDocument) {
        guard document.isDirty else {
            try? recoveryStore.remove(id: document.id)
            return
        }
        do {
            try recoveryStore.save(RecoveryDraft(
                id: document.id,
                text: document.text,
                fileURL: document.fileURL,
                suggestedTitle: document.suggestedTitle,
                lastKnownModificationDate: document.lastKnownModificationDate,
                updatedAt: Date()
            ))
            document.markRecoveryProtected()
        } catch {
            document.markRecoveryFailed(error.localizedDescription)
            NotificationCenter.default.post(
                name: .starMemoRecoveryError,
                object: nil,
                userInfo: ["message": "恢复副本写入失败：\(error.localizedDescription)"]
            )
        }
    }

    private func save(_ document: MarkdownDocument) async -> Bool {
        guard let targetURL = await saveTarget(for: document) else { return false }
        guard canWrite(document, to: targetURL) else { return false }
        do {
            let date = try documentStore.write(
                document.text,
                to: targetURL,
                expectedModificationDate: document.fileURL == nil ? nil : document.lastKnownModificationDate,
                allowOverwrite: document.fileURL == nil
            )
            finishSave(document, to: targetURL, date: date)
            return true
        } catch DocumentStoreError.externalModification {
            return await resolveExternalChange(for: document)
        } catch {
            dialogs.presentError(error)
            return false
        }
    }

    private func saveTarget(for document: MarkdownDocument) async -> URL? {
        if let url = document.fileURL { return url }
        return await dialogs.chooseSaveURL(suggestedTitle: document.displayTitle)
    }

    private func resolveExternalChange(for document: MarkdownDocument) async -> Bool {
        switch await dialogs.decideExternalChange(for: document) {
        case .reload:
            do {
                guard let url = document.fileURL else { return false }
                document.replace(with: try documentStore.load(from: url))
                try? recoveryStore.remove(id: document.id)
                return true
            } catch {
                dialogs.presentError(error)
                return false
            }
        case .overwrite:
            guard let url = document.fileURL else { return false }
            return writeAfterConflict(document, to: url)
        case .saveAs:
            guard let url = await dialogs.chooseSaveURL(suggestedTitle: document.displayTitle) else {
                return false
            }
            return writeAfterConflict(document, to: url)
        case .cancel:
            return false
        }
    }

    private func writeAfterConflict(_ document: MarkdownDocument, to url: URL) -> Bool {
        guard canWrite(document, to: url) else { return false }
        do {
            let date = try documentStore.write(
                document.text,
                to: url,
                expectedModificationDate: nil,
                allowOverwrite: true
            )
            finishSave(document, to: url, date: date)
            return true
        } catch {
            dialogs.presentError(error)
            return false
        }
    }

    private func canWrite(_ document: MarkdownDocument, to url: URL) -> Bool {
        let canonicalURL = canonicalFileURL(url)
        guard !documents.values.contains(where: {
            $0.id != document.id && $0.fileURL.map(canonicalFileURL) == canonicalURL
        }) else {
            dialogs.presentError(DocumentStoreError.fileAlreadyOpen)
            return false
        }
        return true
    }

    private func finishSave(_ document: MarkdownDocument, to url: URL, date: Date?) {
        let oldPreferencesKey = NotePreferencesStore.key(
            documentID: document.id,
            fileURL: document.fileURL
        )
        if let oldURL = document.fileURL.map(canonicalFileURL) {
            documentIDsByURL.removeValue(forKey: oldURL)
        }
        let canonicalURL = canonicalFileURL(url)
        document.markSaved(to: canonicalURL, modificationDate: date)
        migratePreferences(
            from: oldPreferencesKey,
            to: NotePreferencesStore.key(documentID: document.id, fileURL: url)
        )
        documentIDsByURL[canonicalURL] = document.id
        recentDocumentsStore.record(canonicalURL)
        recoveryTasks[document.id]?.cancel()
        try? recoveryStore.remove(id: document.id)
    }

    private func rename(id: UUID, to title: String) {
        guard let document = documents[id] else { return }
        guard let currentURL = document.fileURL else {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                document.suggestedTitle = trimmed
                saveRecovery(for: document)
            }
            return
        }
        do {
            let oldPreferencesKey = NotePreferencesStore.key(
                documentID: id,
                fileURL: currentURL
            )
            let renamedURL = try documentStore.rename(currentURL, to: title)
            documentIDsByURL.removeValue(forKey: currentURL.standardizedFileURL)
            document.moveFile(to: renamedURL)
            migratePreferences(
                from: oldPreferencesKey,
                to: NotePreferencesStore.key(documentID: id, fileURL: renamedURL)
            )
            documentIDsByURL[renamedURL.standardizedFileURL] = id
            recentDocumentsStore.remove(currentURL)
            recentDocumentsStore.record(renamedURL)
            if document.isDirty { saveRecovery(for: document) }
        } catch {
            dialogs.presentError(error)
        }
    }

    private func store(_ preferences: NoteWindowPreferences, for id: UUID) {
        guard let document = documents[id] else { return }
        preferencesStore.save(
            preferences,
            for: NotePreferencesStore.key(documentID: id, fileURL: document.fileURL)
        )
    }

    private func migratePreferences(from oldKey: String, to newKey: String) {
        guard oldKey != newKey,
              let preferences = preferencesStore.load(for: oldKey)
        else { return }
        preferencesStore.save(preferences, for: newKey)
        preferencesStore.remove(for: oldKey)
    }

    private func close(_ document: MarkdownDocument) {
        recoveryTasks[document.id]?.cancel()
        recoveryTasks.removeValue(forKey: document.id)
        try? recoveryStore.remove(id: document.id)
        textObservers.removeValue(forKey: document.id)
        if let url = document.fileURL.map(canonicalFileURL) {
            documentIDsByURL.removeValue(forKey: url)
        }
        windows.removeValue(forKey: document.id)?.closeImmediately()
        documents.removeValue(forKey: document.id)
        if lastActiveDocumentID == document.id {
            lastActiveDocumentID = documents.keys.first
        }
    }

    private func currentDocumentID() -> UUID? {
        windows.first(where: { $0.value.isKeyWindow })?.key ?? lastActiveDocumentID
    }

    private func canonicalFileURL(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    private func markActive(_ id: UUID) {
        guard documents[id] != nil else { return }
        lastActiveDocumentID = id
        if let document = documents[id], document.isDirty {
            saveRecovery(for: document)
        }
    }

    public static let fallbackPreferences = NoteWindowPreferences(
        frame: CGRect(x: 180, y: 180, width: 380, height: 440),
        appearance: .clear,
        opacity: 0.94,
        isPinned: false
    )
}

extension NoteWindowCoordinator: AppCommandRouting {
    public var hasOpenDocuments: Bool { openDocumentCount > 0 }
    public func commandNewNote() { newDocument() }
    public func commandOpen(_ url: URL) throws { try openDocument(at: url) }
    public func commandShowAll() { showAll() }
    public func commandHideAll() { hideAll() }
    public func commandSaveCurrent() async { await saveCurrentDocument() }
    public func commandTogglePinnedCurrent() { togglePinnedCurrentDocument() }
    public func commandRenameCurrent() {
        guard let id = currentDocumentID() else { return }
        windows[id]?.beginRenaming()
    }
    public func commandCloseCurrent() async {
        guard let id = currentDocumentID() else { return }
        _ = await requestClose(id)
    }
    public func commandFlushRecovery() { flushRecoveryDrafts() }
    public func commandRequestQuit() async -> Bool { await requestQuit() }
}
