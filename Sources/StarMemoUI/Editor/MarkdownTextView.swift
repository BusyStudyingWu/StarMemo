import AppKit
import StarMemoCore

private final class MarkdownLayoutManager: NSLayoutManager {
    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        guard let textStorage else { return }
        let characterRange = characterRange(
            forGlyphRange: glyphsToShow,
            actualGlyphRange: nil
        )
        textStorage.enumerateAttribute(
            .starMemoTaskCheckbox,
            in: characterRange
        ) { value, range, _ in
            guard let checked = (value as? NSNumber)?.boolValue else { return }
            let glyphRange = self.glyphRange(
                forCharacterRange: range,
                actualCharacterRange: nil
            )
            guard glyphRange.length > 0 else { return }
            let glyphIndex = glyphRange.location
            let lineRect = self.lineFragmentUsedRect(
                forGlyphAt: glyphIndex,
                effectiveRange: nil
            )
            let glyphLocation = self.location(forGlyphAt: glyphIndex)
            let font = textStorage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
            let size = max(12, font?.pointSize ?? 14)
            let image = NSImage(
                systemSymbolName: checked ? "checkmark.square.fill" : "square",
                accessibilityDescription: checked ? "已完成" : "未完成"
            )
            let rect = NSRect(
                x: origin.x + lineRect.minX + glyphLocation.x,
                y: origin.y + lineRect.minY + (lineRect.height - size) / 2,
                width: size,
                height: size
            )
            image?.draw(in: rect)
        }
    }
}

@MainActor
public final class MarkdownTextView: NSTextView {
    public var onTextChange: (() -> Void)?
    public var onBodyInteraction: (() -> Void)?

    public convenience init() {
        let textStorage = NSTextStorage()
        let layoutManager = MarkdownLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(
            size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        )
        layoutManager.addTextContainer(textContainer)
        self.init(frame: .zero, textContainer: textContainer)
    }

    public override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        configure()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    public func apply(_ command: MarkdownEditingCommand) {
        guard let range = Range(selectedRange(), in: string) else {
            return
        }
        let result = command.apply(to: string, selection: range)
        replaceAllText(with: result.text, selection: NSRange(result.selection, in: result.text))
    }

    @discardableResult
    public func insertMarkdownNewline() -> Bool {
        let selection = selectedRange()
        guard selection.length == 0 else {
            return false
        }

        let nsText = string as NSString
        var lineStart = 0
        var lineEnd = 0
        var contentsEnd = 0
        nsText.getLineStart(
            &lineStart,
            end: &lineEnd,
            contentsEnd: &contentsEnd,
            for: selection
        )
        guard selection.location == contentsEnd else {
            return false
        }
        let lineRange = NSRange(location: lineStart, length: contentsEnd - lineStart)
        let line = nsText.substring(with: lineRange)
        guard let continuation = MarkdownEditingCommand.continuation(forLine: line) else {
            return false
        }

        let mutable = NSMutableString(string: string)
        mutable.replaceCharacters(in: lineRange, with: continuation.lineReplacement)
        let insertionLocation = lineStart + (continuation.lineReplacement as NSString).length
        mutable.insert(continuation.insertion, at: insertionLocation)
        let cursor = insertionLocation + (continuation.insertion as NSString).length
        replaceAllText(
            with: mutable as String,
            selection: NSRange(location: cursor, length: 0)
        )
        return true
    }

    @discardableResult
    public func toggleTask(atUTF16Offset offset: Int) -> Bool {
        guard let index = Range(NSRange(location: offset, length: 0), in: string)?.lowerBound,
              let result = MarkdownEditingCommand.toggleTask(in: string, at: index)
        else {
            return false
        }
        replaceAllText(with: result.text, selection: NSRange(result.selection, in: result.text))
        return true
    }

    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
              let key = event.charactersIgnoringModifiers?.lowercased()
        else {
            return super.performKeyEquivalent(with: event)
        }
        switch key {
        case "b":
            apply(.bold)
        case "i":
            apply(.italic)
        case "k":
            apply(.link)
        default:
            return super.performKeyEquivalent(with: event)
        }
        return true
    }

    public override func insertNewline(_ sender: Any?) {
        if !insertMarkdownNewline() {
            super.insertNewline(sender)
        }
    }

    public override func mouseDown(with event: NSEvent) {
        notifyBodyInteraction()
        if event.modifierFlags.contains(.command) {
            super.mouseDown(with: event)
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        let offset = characterIndexForInsertion(at: point)
        if taskCheckboxRange(atUTF16Offset: offset) != nil,
           toggleTask(atUTF16Offset: offset) {
            return
        }
        super.mouseDown(with: event)
    }

    public func notifyBodyInteraction() {
        onBodyInteraction?()
    }

    public override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        menu.addItem(.separator())
        menu.addItem(withTitle: "Markdown 粗体", action: #selector(formatBold(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Markdown 斜体", action: #selector(formatItalic(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Markdown 删除线", action: #selector(formatStrikethrough(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Markdown 行内代码", action: #selector(formatInlineCode(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Markdown 链接", action: #selector(formatLink(_:)), keyEquivalent: "")
        return menu
    }

    @objc public func formatBold(_ sender: Any?) { apply(.bold) }
    @objc public func formatItalic(_ sender: Any?) { apply(.italic) }
    @objc public func formatStrikethrough(_ sender: Any?) { apply(.strikethrough) }
    @objc public func formatInlineCode(_ sender: Any?) { apply(.inlineCode) }
    @objc public func formatLink(_ sender: Any?) { apply(.link) }

    public func taskCheckboxRange(atUTF16Offset offset: Int) -> NSRange? {
        let nsText = string as NSString
        guard offset >= 0, offset <= nsText.length else { return nil }
        let lookupOffset = min(offset, max(nsText.length - 1, 0))
        var lineStart = 0
        var lineEnd = 0
        var contentsEnd = 0
        nsText.getLineStart(
            &lineStart,
            end: &lineEnd,
            contentsEnd: &contentsEnd,
            for: NSRange(location: lookupOffset, length: 0)
        )
        let lineRange = NSRange(location: lineStart, length: contentsEnd - lineStart)
        guard let expression = try? NSRegularExpression(
            pattern: "^[ \\t]*[-+*][ \\t]+(\\[[ xX]\\])"
        ),
        let match = expression.firstMatch(in: string, range: lineRange),
        match.numberOfRanges > 1
        else {
            return nil
        }
        let checkboxRange = match.range(at: 1)
        return NSLocationInRange(offset, checkboxRange) ? checkboxRange : nil
    }

    private func configure() {
        allowsUndo = true
        isRichText = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isContinuousSpellCheckingEnabled = true
        drawsBackground = false
        textContainerInset = NSSize(width: 18, height: 18)
    }

    private func replaceAllText(with newText: String, selection: NSRange) {
        let oldText = string
        let oldSelection = selectedRange()
        undoManager?.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated {
                target.replaceAllText(with: oldText, selection: oldSelection)
            }
        }
        textStorage?.replaceCharacters(
            in: NSRange(location: 0, length: (string as NSString).length),
            with: newText
        )
        setSelectedRange(selection)
        didChangeText()
        onTextChange?()
    }
}
