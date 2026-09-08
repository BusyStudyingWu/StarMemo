import Combine

@MainActor
public final class LivePreviewState: ObservableObject {
    @Published public private(set) var revealsActiveBlockMarkers = false

    public init() {}

    public func bodyInteraction() {
        revealsActiveBlockMarkers = true
    }

    public func windowBecameKey() {}

    public func windowResignedKey() {
        revealsActiveBlockMarkers = false
    }

    public func applicationResignedActive() {
        revealsActiveBlockMarkers = false
    }
}
