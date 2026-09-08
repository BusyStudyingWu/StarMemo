import Combine
import MarkdownEngine
import StarMemoCore
import SwiftUI

@MainActor
public final class StarMemoMarkdownEditorModel: ObservableObject {
    public let documentID: UUID
    public let livePreviewState: LivePreviewState
    public let commandBus: StarMemoMarkdownCommandBus

    public init(
        documentID: UUID,
        livePreviewState: LivePreviewState,
        commandBus: StarMemoMarkdownCommandBus
    ) {
        self.documentID = documentID
        self.livePreviewState = livePreviewState
        self.commandBus = commandBus
    }

    public var isEditable: Bool {
        livePreviewState.revealsActiveBlockMarkers
    }
}

public struct StarMemoMarkdownEditor: View {
    @Binding private var text: String
    @ObservedObject private var livePreviewState: LivePreviewState
    private let documentID: UUID
    private let appearance: NoteAppearance
    private let fontSize: CGFloat
    private let commandBus: StarMemoMarkdownCommandBus
    private let focusCoordinator: MarkdownEditorFocusCoordinator

    public init(
        text: Binding<String>,
        documentID: UUID,
        appearance: NoteAppearance,
        fontSize: CGFloat,
        livePreviewState: LivePreviewState,
        commandBus: StarMemoMarkdownCommandBus,
        focusCoordinator: MarkdownEditorFocusCoordinator
    ) {
        _text = text
        self.documentID = documentID
        self.appearance = appearance
        self.fontSize = fontSize
        _livePreviewState = ObservedObject(wrappedValue: livePreviewState)
        self.commandBus = commandBus
        self.focusCoordinator = focusCoordinator
    }

    public var body: some View {
        NativeTextViewWrapper(
            text: $text,
            configuration: StarMemoMarkdownThemeFactory.make(
                appearance: appearance,
                fontSize: fontSize,
                bus: commandBus.engineBus
            ),
            fontName: "SF Pro",
            fontSize: fontSize,
            documentId: documentID.uuidString,
            isEditable: livePreviewState.revealsActiveBlockMarkers
        )
        .background(MarkdownEditorFocusResolver(coordinator: focusCoordinator))
    }
}
