import Foundation
import StarMemoCore
import StarMemoTestSupport
import StarMemoUI

@MainActor
let starMemoMarkdownEditorChecks: [Check] = [
    Check("markdown adapter follows live editing state") {
        let state = LivePreviewState()
        let bus = StarMemoMarkdownCommandBus(documentID: UUID())
        let model = StarMemoMarkdownEditorModel(
            documentID: UUID(),
            livePreviewState: state,
            commandBus: bus
        )
        try expect(!model.documentID.uuidString.isEmpty)
        try expect(!model.isEditable)
        state.bodyInteraction()
        try expect(model.isEditable)
    },
    Check("MarkdownDocument remains the sole Markdown source") {
        let source = "# 标题\n- [ ] 待办\n`code`"
        let document = MarkdownDocument(text: source)
        document.text += "\n**粗体**"
        try expect(document.text == source + "\n**粗体**")
        try expect(document.isDirty)
    },
]
