import Foundation
import StarMemoCore
import StarMemoTestSupport
import StarMemoUI

@MainActor
let markdownPreviewUIChecks: [Check] = [
    Check("preview attributed text styles semantic spans") {
        let value = PreviewAttributedStringBuilder(fontSize: 15).build([
            .plain("a "), .bold("bold"), .inlineCode("code"),
        ])
        try expect(String(value.characters) == "a boldcode")
        try expect(value.runs.contains {
            $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true
        })
    },
    Check("preview task toggle preserves every unrelated character") {
        let source = "前言\n- [ ] 做事\n结尾"
        let offset = (source as NSString).range(of: "[ ]").location
        let changed = try require(MarkdownPreviewMutation.toggleTask(
            in: source,
            checkboxUTF16Offset: offset
        ))
        try expect(changed == "前言\n- [x] 做事\n结尾")
    },
    Check("preview code block exposes code without fences") {
        let block = try require(
            MarkdownPreviewBuilder().build("```swift\nlet x = 1\n```").blocks.first
        )
        try expect(block == .codeBlock(language: "swift", code: "let x = 1"))
    },
    Check("preview task round trip preserves mixed UTF-8 source") {
        let source = "# 中文 🌟\n- [ ] 待办 **重要**\n[链接](https://example.com) 和 `code`\n```swift\nlet emoji = \"🚀\"\n```"
        let offset = (source as NSString).range(of: "[ ]").location
        _ = MarkdownPreviewBuilder().build(source)
        let checked = try require(MarkdownPreviewMutation.toggleTask(
            in: source,
            checkboxUTF16Offset: offset
        ))
        let restored = try require(MarkdownPreviewMutation.toggleTask(
            in: checked,
            checkboxUTF16Offset: offset
        ))
        try expect(Array(restored.utf8) == Array(source.utf8))
    },
]
