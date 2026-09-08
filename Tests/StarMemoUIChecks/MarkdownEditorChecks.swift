import AppKit
import StarMemoCore
import StarMemoTestSupport
import StarMemoUI

private func alpha(of color: NSColor?) -> CGFloat {
    color?.usingColorSpace(.deviceRGB)?.alphaComponent ?? 1
}

let markdownEditorChecks: [Check] = [
    Check("markdown text view forwards native body clicks") {
        let textView = MarkdownTextView()
        textView.string = "body"
        var interactionCount = 0
        textView.onBodyInteraction = {
            interactionCount += 1
        }

        textView.notifyBodyInteraction()

        try expect(interactionCount == 1)
    },
    Check("markdown editor pauses styling during marked text input") {
        try expect(!MarkdownEditorView.shouldRestyle(hasMarkedText: true))
        try expect(MarkdownEditorView.shouldRestyle(hasMarkedText: false))
    },
    Check("markdown editor exposes only the selected block after body interaction") {
        let source = "# One\nSecond"
        let result = MarkdownParser().parse(source)
        let first = NSRange(result.blocks[0].range, in: source)
        let second = NSRange(result.blocks[1].range, in: source)

        try expect(MarkdownEditorView.activeBlock(
            in: result,
            selection: NSRange(location: 2, length: 0),
            source: source,
            revealsMarkers: false
        ) == nil)
        try expect(MarkdownEditorView.activeBlock(
            in: result,
            selection: NSRange(location: 2, length: 0),
            source: source,
            revealsMarkers: true
        ) == first)
        try expect(MarkdownEditorView.activeBlock(
            in: result,
            selection: NSRange(location: 8, length: 0),
            source: source,
            revealsMarkers: true
        ) == second)
    },
    Check("markdown editor reads live marker visibility instead of a stale snapshot") {
        let state = LivePreviewState()
        let editor = MarkdownEditorView(
            text: .constant("**bold**"),
            fontSize: 16,
            livePreviewState: state
        )
        try expect(!editor.currentMarkerVisibility)

        state.bodyInteraction()

        try expect(editor.currentMarkerVisibility)
    },
    Check("markdown editor coordinator hides markers immediately on app deactivation") {
        let state = LivePreviewState()
        let editor = MarkdownEditorView(
            text: .constant("**bold**"),
            fontSize: 16,
            livePreviewState: state
        )
        let coordinator = editor.makeCoordinator()
        state.bodyInteraction()

        coordinator.applicationResignedActive()

        try expect(!state.revealsActiveBlockMarkers)
    },
    Check("markdown editor styler preserves source and applies semantic fonts") {
        let source = "# Heading\n**bold**\n`code`"
        let storage = NSTextStorage(string: source)
        let parseResult = MarkdownParser().parse(source)
        MarkdownTextStyler(fontSize: 16).apply(
            source: source,
            activeBlock: NSRange(location: 10, length: 8),
            parseResult: parseResult,
            to: storage
        )
        try expect(storage.string == source)
        let headingFont = storage.attribute(.font, at: 2, effectiveRange: nil) as? NSFont
        let boldFont = storage.attribute(.font, at: 13, effectiveRange: nil) as? NSFont
        let codeFont = storage.attribute(.font, at: 22, effectiveRange: nil) as? NSFont
        try expect((headingFont?.pointSize ?? 0) > 16)
        try expect(NSFontManager.shared.traits(of: boldFont ?? .systemFont(ofSize: 16)).contains(.boldFontMask))
        try expect(NSFontManager.shared.traits(of: codeFont ?? .systemFont(ofSize: 16)).contains(.fixedPitchFontMask))
    },
    Check("markdown editor styler collapses inactive markers without changing source") {
        let source = "**bold**\nplain"
        let storage = NSTextStorage(string: source)
        let result = MarkdownParser().parse(source)
        let styler = MarkdownTextStyler(fontSize: 16)
        styler.apply(
            source: source,
            activeBlock: NSRange(location: 9, length: 5),
            parseResult: result,
            to: storage
        )
        let inactive = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        let inactiveFont = storage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let boldFont = storage.attribute(.font, at: 2, effectiveRange: nil) as? NSFont
        try expect(alpha(of: inactive) == 0)
        try expect((inactiveFont?.pointSize ?? 16) < 1)
        try expect(NSFontManager.shared.traits(of: boldFont ?? .systemFont(ofSize: 16)).contains(.boldFontMask))
        try expect(storage.string == source)

        styler.apply(
            source: source,
            activeBlock: NSRange(location: 0, length: 8),
            parseResult: result,
            to: storage
        )
        let active = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        let activeFont = storage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        try expect(alpha(of: active) > 0.2 && alpha(of: active) < 0.75)
        try expect((activeFont?.pointSize ?? 0) > 10)
        try expect(storage.string == source)
    },
    Check("markdown editor text view applies formatting and preserves selection") {
        let textView = MarkdownTextView()
        textView.string = "hello"
        textView.setSelectedRange(NSRange(location: 0, length: 5))
        textView.apply(.bold)
        try expect(textView.string == "**hello**")
        try expect(textView.selectedRange() == NSRange(location: 2, length: 5))
    },
    Check("markdown editor text view continues lists") {
        let textView = MarkdownTextView()
        textView.string = "- item"
        textView.setSelectedRange(NSRange(location: 6, length: 0))
        try expect(textView.insertMarkdownNewline())
        try expect(textView.string == "- item\n- ")
        try expect(textView.selectedRange().location == 9)
    },
    Check("markdown editor only toggles a task from its checkbox") {
        let textView = MarkdownTextView()
        textView.string = "- [ ] task words"

        try expect(textView.taskCheckboxRange(atUTF16Offset: 3) != nil)
        try expect(textView.taskCheckboxRange(atUTF16Offset: 8) == nil)
    },
    Check("markdown editor marks an inactive task for native checkbox drawing") {
        let source = "- [ ] task"
        let storage = NSTextStorage(string: source)
        MarkdownTextStyler(fontSize: 16).apply(
            source: source,
            activeBlock: nil,
            parseResult: MarkdownParser().parse(source),
            to: storage
        )

        try expect(
            storage.attribute(.starMemoTaskCheckbox, at: 3, effectiveRange: nil) != nil,
            "Inactive checkbox should carry a native-drawing attribute"
        )
        try expect(storage.string == source, "Styling must not replace the Markdown source")

        MarkdownTextStyler(fontSize: 16).apply(
            source: source,
            activeBlock: NSRange(location: 0, length: (source as NSString).length),
            parseResult: MarkdownParser().parse(source),
            to: storage
        )
        try expect(
            storage.attribute(.starMemoTaskCheckbox, at: 3, effectiveRange: nil) == nil,
            "Active checkbox should reveal its Markdown characters"
        )
    },
    Check("markdown editor styles links with their destination") {
        let source = "[OpenAI](https://openai.com)"
        let storage = NSTextStorage(string: source)
        MarkdownTextStyler(fontSize: 16).apply(
            source: source,
            activeBlock: nil,
            parseResult: MarkdownParser().parse(source),
            to: storage
        )
        let link = storage.attribute(.link, at: 2, effectiveRange: nil) as? URL
        try expect(link?.absoluteString == "https://openai.com")
    },
]
