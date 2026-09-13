import Combine

/// Keeps the last active note selected when the settings window becomes key.
@MainActor
public final class NoteSettingsSelection: ObservableObject {
    @Published public private(set) var current: NoteWindowController?
    public init() {}
    func select(_ controller: NoteWindowController?) {
        guard current !== controller else { return }
        current = controller
    }
}
