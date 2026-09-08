import CoreGraphics
import StarMemoTestSupport
import StarMemoUI

@MainActor
private final class NativeFocusTargetSpy: MarkdownEditorNativeFocusTarget {
    var isEditable = false
    var hasMarkedText = false
    var hitResult: Bool
    var restyleCount = 0
    var bodyInteractionCount = 0
    var selectionMutationCount = 0

    init(hitResult: Bool = true) {
        self.hitResult = hitResult
    }

    func contains(windowPoint: CGPoint) -> Bool { hitResult }
    func restyleForFocusChange() { restyleCount += 1 }
}

@MainActor
let markdownEditorFocusBridgeChecks: [Check] = [
    Check("focus bridge deactivates without moving selection") {
        let state = LivePreviewState()
        state.bodyInteraction()
        let target = NativeFocusTargetSpy()
        target.isEditable = true
        let bridge = MarkdownEditorFocusCoordinator(
            state: state,
            onBodyInteraction: {}
        )
        bridge.attach(target)
        bridge.deactivate()
        try expect(!target.isEditable)
        try expect(!state.revealsActiveBlockMarkers)
        try expect(target.restyleCount == 1)
        try expect(target.selectionMutationCount == 0)
    },
    Check("first body mouse down re-enables before forwarding") {
        let state = LivePreviewState()
        let target = NativeFocusTargetSpy(hitResult: true)
        let bridge = MarkdownEditorFocusCoordinator(
            state: state,
            onBodyInteraction: { target.bodyInteractionCount += 1 }
        )
        bridge.attach(target)
        try expect(bridge.handleMouseDown(windowPoint: .zero))
        try expect(target.isEditable)
        try expect(state.revealsActiveBlockMarkers)
        try expect(target.bodyInteractionCount == 1)
    },
    Check("focus bridge ignores title-bar mouse downs") {
        let state = LivePreviewState()
        let target = NativeFocusTargetSpy(hitResult: false)
        let bridge = MarkdownEditorFocusCoordinator(
            state: state,
            onBodyInteraction: { target.bodyInteractionCount += 1 }
        )
        bridge.attach(target)
        try expect(!bridge.handleMouseDown(windowPoint: .zero))
        try expect(!target.isEditable)
        try expect(target.bodyInteractionCount == 0)
    },
]
