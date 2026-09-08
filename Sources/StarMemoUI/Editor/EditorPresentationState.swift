import Combine

public enum EditorPresentationMode: Equatable, Sendable {
    case editing
    case previewing
}

@MainActor
public final class EditorPresentationState: ObservableObject {
    @Published public private(set) var mode: EditorPresentationMode
    @Published public private(set) var isWindowKey = true
    public private(set) var isComposingText = false

    public init(initialMode: EditorPresentationMode = .editing) {
        mode = initialMode
    }

    public func windowBecameKey() {
        isWindowKey = true
    }

    public func windowResignedKey() {
        isWindowKey = false
        if !isComposingText {
            mode = .previewing
        }
    }

    public func setComposingText(_ composing: Bool) {
        isComposingText = composing
        if !composing && !isWindowKey {
            mode = .previewing
        }
    }

    public func requestEditing() {
        mode = .editing
    }
}
