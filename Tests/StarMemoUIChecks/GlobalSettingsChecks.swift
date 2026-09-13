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
        windowFactory: { [unowned self] document, preferences, close, rename, persist, activate in
            let controller = NoteWindowController(
                document: document, preferences: preferences, fontSize: 15, settings: settings,
                onCloseRequest: close, onRename: rename, onPreferencesChange: persist, onActivate: activate
            )
            windows[document.id] = controller
            return controller
        }
    )

    init() {
        defaults = UserDefaults(suiteName: suite)!
        settings = AppSettings(defaults: defaults)
        root = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
    }

    func cleanUp() {
        windows.values.forEach { $0.closeImmediately() }
        defaults.removePersistentDomain(forName: suite)
    }
}

let globalSettingsChecks: [Check] = [
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
    Check("global settings override saved appearance on reopen without moving the note") {
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
        try expect(reopenedWindow.state.appearance == .lavender, "Saved per-note appearance overrode global settings")
        try expect(reopenedWindow.state.opacity == 0 && reopenedWindow.state.isPinned)
        try expect(reopenedWindow.window?.frame == frame)
        let persistedBody = try Data(contentsOf: url)
        try expect(persistedBody == original)
    },
]
