import AppKit
import StarMemoCore

public extension NSAttributedString.Key {
    static let starMemoTaskCheckbox = NSAttributedString.Key("StarMemoTaskCheckbox")
}

@MainActor
public final class MarkdownTextStyler {
    private let fontSize: CGFloat

    public init(fontSize: CGFloat) {
        self.fontSize = fontSize
    }

    public func apply(
        source: String,
        activeBlock: NSRange?,
        parseResult: MarkdownParseResult,
        to storage: NSTextStorage
    ) {
        guard storage.string == source else {
            return
        }

        let fullRange = NSRange(location: 0, length: (source as NSString).length)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.paragraphSpacing = 5
        storage.beginEditing()
        storage.setAttributes([
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph,
        ], range: fullRange)

        for token in parseResult.tokens {
            let tokenRange = NSRange(token.range, in: source)
            let contentRange = NSRange(token.contentRange, in: source)
            applySemanticStyle(for: token.kind, range: contentRange, to: storage)

            let tokenIsActive = isActive(tokenRange, activeBlock: activeBlock)
            for marker in token.markerRanges {
                let markerRange = NSRange(marker, in: source)
                if tokenIsActive {
                    storage.addAttributes([
                        .font: NSFont.systemFont(ofSize: fontSize),
                        .foregroundColor: NSColor.tertiaryLabelColor.withAlphaComponent(0.48),
                    ], range: markerRange)
                } else {
                    storage.addAttributes([
                        .font: NSFont.systemFont(ofSize: 0.1),
                        .foregroundColor: NSColor.clear,
                    ], range: markerRange)
                }
            }
            if case let .task(checked) = token.kind, !tokenIsActive,
               let marker = token.markerRanges.first {
                applyTaskAttachment(
                    checked: checked,
                    markerRange: NSRange(marker, in: source),
                    source: source,
                    to: storage
                )
            }
        }
        storage.endEditing()
    }

    private func applyTaskAttachment(
        checked: Bool,
        markerRange: NSRange,
        source: String,
        to storage: NSTextStorage
    ) {
        let markerText = (source as NSString).substring(with: markerRange)
        guard let expression = try? NSRegularExpression(pattern: "\\[([ xX])\\]"),
              let match = expression.firstMatch(
                in: markerText,
                range: NSRange(location: 0, length: (markerText as NSString).length)
              )
        else {
            return
        }
        let checkboxCharacter = NSRange(
            location: markerRange.location + match.range(at: 1).location,
            length: match.range(at: 1).length
        )
        storage.addAttributes([
            .starMemoTaskCheckbox: NSNumber(value: checked),
            .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: NSColor.clear,
            .kern: fontSize * 0.35,
        ], range: checkboxCharacter)
    }

    private func applySemanticStyle(
        for kind: MarkdownTokenKind,
        range: NSRange,
        to storage: NSTextStorage
    ) {
        switch kind {
        case let .heading(level):
            let scales: [CGFloat] = [1.75, 1.5, 1.3, 1.18, 1.08, 1.0]
            let scale = scales[min(max(level - 1, 0), scales.count - 1)]
            storage.addAttribute(
                .font,
                value: NSFont.systemFont(ofSize: fontSize * scale, weight: .semibold),
                range: range
            )
        case .bold:
            convertFont(in: range, trait: .boldFontMask, storage: storage)
        case .italic:
            convertFont(in: range, trait: .italicFontMask, storage: storage)
        case .strikethrough:
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        case .inlineCode, .fencedCode:
            storage.addAttributes([
                .font: NSFont.monospacedSystemFont(ofSize: fontSize * 0.93, weight: .regular),
                .backgroundColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.12),
            ], range: range)
        case let .link(destination):
            var attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ]
            if let url = URL(string: destination) {
                attributes[.link] = url
            }
            storage.addAttributes(attributes, range: range)
        case .blockquote:
            storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: range)
        case .unorderedList, .orderedList, .task:
            let listParagraph = NSMutableParagraphStyle()
            listParagraph.firstLineHeadIndent = 0
            listParagraph.headIndent = 18
            listParagraph.lineSpacing = 3
            storage.addAttribute(.paragraphStyle, value: listParagraph, range: range)
        }
    }

    private func convertFont(
        in range: NSRange,
        trait: NSFontTraitMask,
        storage: NSTextStorage
    ) {
        let current = storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
            ?? NSFont.systemFont(ofSize: fontSize)
        let converted = NSFontManager.shared.convert(current, toHaveTrait: trait)
        storage.addAttribute(.font, value: converted, range: range)
    }

    private func isActive(_ tokenRange: NSRange, activeBlock: NSRange?) -> Bool {
        guard let activeBlock else {
            return false
        }
        if activeBlock.length == 0 {
            return activeBlock.location >= tokenRange.location
                && activeBlock.location <= NSMaxRange(tokenRange)
        }
        return NSIntersectionRange(tokenRange, activeBlock).length > 0
    }
}
