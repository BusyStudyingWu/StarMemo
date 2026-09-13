import AppKit
import Combine
import StarMemoCore
import SwiftUI

@MainActor
public final class NoteWindowState: ObservableObject {
    @Published public var appearance: NoteAppearance
    @Published public var opacity: Double
    @Published public var fontSize: CGFloat
    @Published public private(set) var isPinned: Bool
    public let titleBar = TitleBarState()
    public let editorPresentation = EditorPresentationState()
    public let livePreview = LivePreviewState()
    public let markdownCommandBus: StarMemoMarkdownCommandBus

    public init(preferences: NoteWindowPreferences, documentID: UUID, fontSize: CGFloat = 15) {
        appearance = preferences.appearance
        opacity = preferences.opacity.isFinite ? min(max(preferences.opacity, 0), 1) : 1
        isPinned = preferences.isPinned
        self.fontSize = fontSize
        markdownCommandBus = StarMemoMarkdownCommandBus(documentID: documentID)
    }

    public func togglePinned() {
        isPinned.toggle()
    }

    public func normalizeOpacity() {
        opacity = opacity.isFinite ? min(max(opacity, 0), 1) : 1
    }

    public func windowBecameKey() {
        editorPresentation.windowBecameKey()
        livePreview.windowBecameKey()
    }

    public func windowResignedKey() {
        editorPresentation.windowResignedKey()
        livePreview.windowResignedKey()
    }

    public func requestBodyEditing() {
        editorPresentation.requestEditing()
        livePreview.bodyInteraction()
    }

    public func requestBodyInteraction() {
        titleBar.requestBodyInteraction()
        livePreview.bodyInteraction()
    }

    public func applicationResignedActive() {
        livePreview.applicationResignedActive()
    }

    public func setComposingText(_ value: Bool) {
        editorPresentation.setComposingText(value)
    }

    public func togglePreviewTask(in document: MarkdownDocument, checkboxUTF16Offset: Int) {
        guard let changed = MarkdownPreviewMutation.toggleTask(
            in: document.text,
            checkboxUTF16Offset: checkboxUTF16Offset
        ) else {
            return
        }
        document.text = changed
    }
}

public struct NoteWindowView: View {
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    private let reduceTransparencyOverride: Bool?
    private var reduceTransparency: Bool { reduceTransparencyOverride ?? systemReduceTransparency }
    @ObservedObject private var document: MarkdownDocument
    @ObservedObject private var state: NoteWindowState
    @ObservedObject private var livePreview: LivePreviewState
    private let focusCoordinator: MarkdownEditorFocusCoordinator
    private let onRename: (String) -> Void
    private let onTogglePinned: () -> Void
    private let onAppearanceChange: (NoteAppearance) -> Void
    private let onClose: () -> Void

    public init(
        document: MarkdownDocument,
        state: NoteWindowState,
        focusCoordinator: MarkdownEditorFocusCoordinator,
        onRename: @escaping (String) -> Void,
        onTogglePinned: @escaping () -> Void,
        onAppearanceChange: @escaping (NoteAppearance) -> Void,
        onClose: @escaping () -> Void,
        reduceTransparencyOverride: Bool? = nil
    ) {
        _document = ObservedObject(wrappedValue: document)
        _state = ObservedObject(wrappedValue: state)
        _livePreview = ObservedObject(wrappedValue: state.livePreview)
        self.focusCoordinator = focusCoordinator
        self.onRename = onRename
        self.onTogglePinned = onTogglePinned
        self.onAppearanceChange = onAppearanceChange
        self.onClose = onClose
        self.reduceTransparencyOverride = reduceTransparencyOverride
    }

    public var body: some View {
        let palette = NoteColorPalette(appearance: state.appearance)
        ZStack(alignment: .top) {
            NoteBackgroundView(appearance: state.appearance, opacity: state.opacity, reduceTransparency: reduceTransparency)
            StarMemoMarkdownEditor(
                text: Binding(
                    get: { document.text },
                    set: { document.text = $0 }
                ),
                documentID: document.id,
                appearance: state.appearance,
                fontSize: state.fontSize,
                livePreviewState: livePreview,
                commandBus: state.markdownCommandBus,
                focusCoordinator: focusCoordinator
            )
            CollapsibleTitleBar(
                title: document.displayTitle,
                storageStatus: document.storageStatusTitle,
                storageDetail: document.storageStatusDetail,
                titleBarState: state.titleBar,
                windowState: state,
                onRename: onRename,
                onTogglePinned: onTogglePinned,
                onAppearanceChange: onAppearanceChange,
                onClose: onClose
            )
        }
        .foregroundStyle(Color(nsColor: palette.ink))
        .overlay(alignment: .bottomLeading) {
            if case .failed(let message) = document.draftProtection, document.isDirty {
                Text("恢复副本失败，请按 ⌘S 保存")
                    .font(.caption)
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .help(message)
                    .accessibilityLabel(document.storageStatusDetail)
                    .padding(8)
            }
        }
        .environment(\.colorScheme, state.appearance == .graphite ? .dark : .light)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
