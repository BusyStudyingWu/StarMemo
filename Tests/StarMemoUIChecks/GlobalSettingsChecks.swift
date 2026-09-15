import AppKit
import StarMemoCore
import StarMemoTestSupport
import StarMemoUI

@MainActor
private final class GlobalSettingsFixture {
    let suite = "GlobalSettings.\(UUID().uuidString)"
    let defaults: UserDefaults
    let settings: AppSettings
    let root: URL
    var windows: [UUID: NoteWindowController] = [:]
    lazy var coordinator = NoteWindowCoordinator(
        documentStore: DocumentStore(),
        recoveryStore: DraftRecoveryStore(directory: root),
        recentDocumentsStore: RecentDocumentsStore(defaults: defaults),
        preferencesStore: NotePreferencesStore(defaults: defaults),
        dialogs: AppKitDocumentDialogPresenter(),
        defaultPreferencesProvider: { [unowned self] in
            NoteWindowPreferences(frame: NoteWindowCoordinator.fallbackPreferences.frame,
                appearance: settings.defaultAppearance, opacity: settings.windowOpacity,
                isPinned: settings.defaultPinned)
        },
        windowFactory: { [unowned self] document, preferences, close, rename, persist, activate in
            let controller = NoteWindowController(
                document: document, preferences: preferences, fontSize: 15, settings: settings,
                onCloseRequest: close, onRename: rename, onPreferencesChange: persist, onActivate: activate
            )
            windows[document.id] = controller
            return controller
        }
    )

    init(root existingRoot: URL? = nil) {
        defaults = UserDefaults(suiteName: suite)!
        settings = AppSettings(defaults: defaults)
        root = existingRoot ?? FileManager.default.temporaryDirectory.appendingPathComponent(suite)
    }

    func cleanUp() {
        windows.values.forEach { $0.closeImmediately() }
        defaults.removePersistentDomain(forName: suite)
    }
}

let globalSettingsChecks: [Check] = [
    Check("session appearance survives quit and real window restoration with global updates") {
        let first = GlobalSettingsFixture()
        defer { first.cleanUp() }
        let document = first.coordinator.newDocument(text: "preserve body")
        let window = try require(first.windows[document.id])
        window.setAppearance(.warmYellow)
        window.setOpacity(0.45)
        window.togglePinned()
        let frame = try require(window.window?.frame)
        let quit = await first.coordinator.requestQuit()
        try expect(quit)
        first.windows.values.forEach { $0.closeImmediately() }
        let next = GlobalSettingsFixture(root: first.root)
        defer { next.cleanUp() }
        try next.coordinator.restoreDrafts()
        let restored = try require(next.windows[document.id])
        try expect(restored.state.appearance == .warmYellow, "Restoration replaced saved theme with default")
        try expect(restored.state.opacity == 0.45 && restored.state.isPinned)
        try expect(restored.window?.level == .floating && restored.window?.frame == frame)
        next.settings.defaultAppearance = .lavender
        next.settings.windowOpacity = 0.7
        next.settings.defaultPinned = false
        try expect(restored.state.appearance == .lavender && restored.state.opacity == 0.7)
        try expect(!restored.state.isPinned && restored.window?.level == .normal)
        let fresh = next.coordinator.newDocument()
        let freshWindow = try require(next.windows[fresh.id])
        try expect(freshWindow.state.appearance == .lavender && freshWindow.state.opacity == 0.7 && !freshWindow.state.isPinned)
        let secondQuit = await next.coordinator.requestQuit()
        try expect(secondQuit)
        next.windows.values.forEach { $0.closeImmediately() }
        let third = GlobalSettingsFixture(root: first.root)
        defer { third.cleanUp() }
        try third.coordinator.restoreDrafts()
        let again = try require(third.windows[document.id])
        try expect(again.state.appearance == .lavender && again.state.opacity == 0.7 && !again.state.isPinned)
        try expect(third.coordinator.document(id: document.id)?.text == "preserve body")
    },
    Check("initial global subscription does not overwrite supplied window preferences") {
        let fixture = GlobalSettingsFixture()
        defer { fixture.cleanUp() }
        let document = MarkdownDocument(text: "test")
        let window = NoteWindowController(document: document,
            preferences: NoteWindowPreferences(frame: NoteWindowCoordinator.fallbackPreferences.frame,
                appearance: .graphite, opacity: 0.35, isPinned: true), fontSize: 15, settings: fixture.settings,
            onCloseRequest: { _ in }, onRename: { _, _ in }, onPreferencesChange: { _, _ in }, onActivate: { _ in })
        defer { window.closeImmediately() }
        try expect(window.state.appearance == .graphite && window.state.opacity == 0.35)
        try expect(window.state.isPinned && window.window?.level == .floating)
    },
    Check("global settings update all existing notes and preserve body and local shortcuts") {
        let fixture = GlobalSettingsFixture()
        defer { fixture.cleanUp() }
        let first = fixture.coordinator.newDocument(suggestedTitle: "first")
        let second = fixture.coordinator.newDocument(suggestedTitle: "second")
        let firstWindow = try require(fixture.windows[first.id])
        let secondWindow = try require(fixture.windows[second.id])
        fixture.settings.defaultAppearance = .graphite
        fixture.settings.windowOpacity = 0.5
        fixture.settings.defaultPinned = true
        fixture.settings.editorFontSize = 21
        for controller in [firstWindow, secondWindow] {
            try expect(controller.state.appearance == .graphite, "Existing note did not receive global color")
            try expect(controller.window?.appearance?.name == .darkAqua)
            try expect(controller.state.opacity == 0.5, "Existing note did not receive actual alpha")
            try expect(controller.window?.alphaValue == 1, "Whole-window alpha must remain opaque")
            try expect(controller.window?.level == .floating)
            try expect(controller.state.fontSize == 21)
        }
        firstWindow.togglePinned()
        firstWindow.setAppearance(.warmYellow)
        fixture.settings.editorFontSize = 18
        try expect(!firstWindow.state.isPinned && secondWindow.state.isPinned)
        try expect(firstWindow.state.appearance == .warmYellow && secondWindow.state.appearance == .graphite)
        fixture.settings.defaultPinned = true
        fixture.settings.defaultAppearance = .graphite
        try expect(firstWindow.state.isPinned && firstWindow.state.appearance == .graphite)
        let third = fixture.coordinator.newDocument()
        let thirdWindow = try require(fixture.windows[third.id])
        try expect(thirdWindow.state.appearance == .graphite && thirdWindow.state.opacity == 0.5 && thirdWindow.state.isPinned)
        try expect(first.text.isEmpty && second.text.isEmpty && !first.isDirty && !second.isDirty)
    },
    Check("reopening a saved note keeps its last appearance without moving the note") {
        let fixture = GlobalSettingsFixture()
        defer { fixture.cleanUp() }
        try FileManager.default.createDirectory(at: fixture.root, withIntermediateDirectories: true)
        let url = fixture.root.appendingPathComponent("reopen.md")
        let original = Data("# Keep this Markdown\n- [ ] task".utf8)
        try original.write(to: url)
        let document = try fixture.coordinator.openDocument(at: url)
        let controller = try require(fixture.windows[document.id])
        controller.setAppearance(.warmYellow)
        let frame = try require(controller.window?.frame)
        let closed = await fixture.coordinator.requestClose(document.id)
        try expect(closed)
        fixture.settings.defaultAppearance = .lavender
        fixture.settings.windowOpacity = 0
        fixture.settings.defaultPinned = true
        let reopened = try fixture.coordinator.openDocument(at: url)
        let reopenedWindow = try require(fixture.windows[reopened.id])
        try expect(reopenedWindow.state.appearance == .warmYellow, "Reopen discarded saved per-note appearance")
        try expect(reopenedWindow.state.opacity == controller.state.opacity && reopenedWindow.state.isPinned == controller.state.isPinned)
        try expect(reopenedWindow.window?.frame == frame)
        let persistedBody = try Data(contentsOf: url)
        try expect(persistedBody == original)
    },
]
