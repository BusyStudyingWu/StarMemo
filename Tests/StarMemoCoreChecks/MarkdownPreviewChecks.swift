import Foundation
import StarMemoCore
import StarMemoTestSupport

let markdownPreviewChecks: [Check] = [
    Check("preview builder creates semantic blocks without markdown markers") {
        let source = "# 标题\n\n普通 **粗体** 和 `code`\n- [ ] 待办\n> 引用\n```swift\nlet n = 1\n```"
        let checkboxOffset = (source as NSString).range(of: "[ ]").location
        let preview = MarkdownPreviewBuilder().build(source)

        try expect(preview.blocks.contains(.heading(level: 1, spans: [.plain("标题")])))
        try expect(preview.blocks.contains(.paragraph(spans: [
            .plain("普通 "),
            .bold("粗体"),
            .plain(" 和 "),
            .inlineCode("code"),
        ])))
        try expect(preview.blocks.contains(.task(
            checked: false,
            text: "待办",
            sourceUTF16Offset: checkboxOffset
        )))
        try expect(preview.blocks.contains(.blockquote(spans: [.plain("引用")])))
        try expect(preview.blocks.contains(.codeBlock(language: "swift", code: "let n = 1")))
        try expect(!preview.visiblePlainText.contains("```"))
        try expect(!preview.visiblePlainText.contains("[ ]"))
    },
    Check("preview builder preserves unsupported text") {
        let source = "plain <custom> text"
        try expect(MarkdownPreviewBuilder().build(source).visiblePlainText == source)
    },
    Check("preview builder preserves an unclosed fence as plain text") {
        let source = "```swift\nlet n = 1"
        let preview = MarkdownPreviewBuilder().build(source)
        try expect(preview.visiblePlainText == source)
        try expect(!preview.blocks.contains { block in
            if case .codeBlock = block { return true }
            return false
        })
    },
]
