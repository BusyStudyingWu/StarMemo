import AppKit
import StarMemoTestSupport
import StarMemoUI

@main
struct UIChecks {
    @MainActor
    static func main() {
        NSApplication.shared.setActivationPolicy(.accessory)
        Task { @MainActor in
            await runChecks()
            NSApplication.shared.terminate(nil)
        }
        NSApplication.shared.run()
    }

    @MainActor
    static func runChecks() async {
        await TestHarness.run([
            Check("UI module loads") {
                try expect(StarMemoUI.moduleName == "StarMemoUI")
            },
        ] + markdownEngineDependencyChecks
            + starMemoMarkdownConfigurationChecks
            + starMemoMarkdownEditorChecks
            + markdownEditorFocusBridgeChecks
            + markdownCommandRelayChecks
            + (markdownEditorChecks + editorPresentationChecks + markdownPreviewUIChecks).map {
                Check("legacy: " + $0.name, body: $0.body)
            }
            + noteWindowChecks
            + currentNoteSettingsChecks
            + globalSettingsChecks
            + transparencyRenderingChecks
            + noteWindowCoordinatorChecks
            + statusBarIconChecks
            + appControllerChecks)
    }
}
