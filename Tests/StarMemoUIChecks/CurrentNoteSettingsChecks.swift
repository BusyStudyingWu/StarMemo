import AppKit
import StarMemoCore
import StarMemoTestSupport
import StarMemoUI

// Regression for the former current-note controls: local shortcuts stay local,
// and closed windows must stop receiving global updates.
let currentNoteSettingsChecks: [Check] = [
    Check("closed note stops receiving global settings") {
        let suite = "ClosedSettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        let controller = NoteWindowController(
            document: MarkdownDocument(), preferences: NoteWindowCoordinator.fallbackPreferences,
            fontSize: 15, settings: settings, onCloseRequest: { _ in }, onRename: { _, _ in },
            onPreferencesChange: { _, _ in }, onActivate: { _ in }
        )
        controller.closeImmediately()
        let previous = controller.state.appearance
        let previousSize = controller.state.fontSize
        settings.defaultAppearance = .graphite
        settings.editorFontSize = 25
        try expect(controller.state.appearance == previous && controller.state.fontSize == previousSize)
    },
]
