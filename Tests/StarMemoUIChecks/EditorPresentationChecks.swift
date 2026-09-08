import StarMemoTestSupport
import StarMemoUI

@MainActor
let editorPresentationChecks: [Check] = [
    Check("live preview reveals source only after a body interaction") {
        let state = LivePreviewState()
        try expect(!state.revealsActiveBlockMarkers)

        state.bodyInteraction()
        try expect(state.revealsActiveBlockMarkers)
    },
    Check("live preview hides source when focus leaves and stays hidden on return") {
        let state = LivePreviewState()
        state.bodyInteraction()
        state.windowResignedKey()
        try expect(!state.revealsActiveBlockMarkers)

        state.windowBecameKey()
        try expect(!state.revealsActiveBlockMarkers)

        state.bodyInteraction()
        state.applicationResignedActive()
        try expect(!state.revealsActiveBlockMarkers)
    },
    Check("editor previews after window resigns and edits on request") {
        let state = EditorPresentationState(initialMode: .editing)
        state.windowResignedKey()
        try expect(state.mode == .previewing)
        state.windowBecameKey()
        try expect(state.mode == .previewing, "Task clicks may activate without editing")
        state.requestEditing()
        try expect(state.mode == .editing)
    },
    Check("marked text defers preview until composition ends") {
        let state = EditorPresentationState(initialMode: .editing)
        state.setComposingText(true)
        state.windowResignedKey()
        try expect(state.mode == .editing)
        state.setComposingText(false)
        try expect(state.mode == .previewing)
    },
]
