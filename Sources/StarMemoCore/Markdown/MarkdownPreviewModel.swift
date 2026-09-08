import Foundation

public enum MarkdownPreviewSpan: Equatable, Sendable {
    case plain(String)
    case bold(String)
    case italic(String)
    case strikethrough(String)
    case link(label: String, destination: String)
    case inlineCode(String)
}

public enum MarkdownPreviewBlock: Equatable, Sendable {
    case heading(level: Int, spans: [MarkdownPreviewSpan])
    case paragraph(spans: [MarkdownPreviewSpan])
    case unorderedItem(spans: [MarkdownPreviewSpan])
    case orderedItem(number: Int, spans: [MarkdownPreviewSpan])
    case task(checked: Bool, text: String, sourceUTF16Offset: Int)
    case blockquote(spans: [MarkdownPreviewSpan])
    case codeBlock(language: String?, code: String)
    case blank
}

public struct MarkdownPreviewDocument: Equatable, Sendable {
    public let blocks: [MarkdownPreviewBlock]
    public let visiblePlainText: String

    public init(blocks: [MarkdownPreviewBlock], visiblePlainText: String) {
        self.blocks = blocks
        self.visiblePlainText = visiblePlainText
    }
}

public struct MarkdownPreviewBuilder: Sendable {
    public init() {}

    public func build(_ source: String) -> MarkdownPreviewDocument {
        guard !source.isEmpty else {
            return MarkdownPreviewDocument(blocks: [], visiblePlainText: "")
        }

        let parseResult = MarkdownParser().parse(source)
        let sourceNSString = source as NSString
        let tokens = parseResult.tokens.map { token in
            (token: token, range: NSRange(token.range, in: source), contentRange: NSRange(token.contentRange, in: source))
        }
        var blocks: [MarkdownPreviewBlock] = []
        var location = 0

        while location < sourceNSString.length {
            var lineStart = 0
            var lineEnd = 0
            var contentsEnd = 0
            sourceNSString.getLineStart(
                &lineStart,
                end: &lineEnd,
                contentsEnd: &contentsEnd,
                for: NSRange(location: location, length: 0)
            )

            if let fence = tokens.first(where: { item in
                item.range.location == lineStart && item.token.kind == .fencedCode
            }) {
                let openingLine = sourceNSString.substring(
                    with: NSRange(location: lineStart, length: contentsEnd - lineStart)
                )
                let language = fenceLanguage(from: openingLine)
                let rawCode = sourceNSString.substring(with: fence.contentRange)
                blocks.append(.codeBlock(language: language, code: droppingOneTrailingNewline(from: rawCode)))
                location = NSMaxRange(fence.range)
                continue
            }

            let lineRange = NSRange(location: lineStart, length: contentsEnd - lineStart)
            let line = sourceNSString.substring(with: lineRange)
            blocks.append(block(for: line, lineRange: lineRange, source: source, tokens: tokens))
            location = lineEnd
        }

        return MarkdownPreviewDocument(
            blocks: blocks,
            visiblePlainText: blocks.map(visibleText).joined(separator: "\n")
        )
    }

    private func block(
        for line: String,
        lineRange: NSRange,
        source: String,
        tokens: [(token: MarkdownToken, range: NSRange, contentRange: NSRange)]
    ) -> MarkdownPreviewBlock {
        guard !line.isEmpty else { return .blank }

        let blockToken = tokens.first { item in
            item.range.location >= lineRange.location
                && NSMaxRange(item.range) <= NSMaxRange(lineRange)
                && isBlockKind(item.token.kind)
        }

        guard let blockToken else {
            return .paragraph(spans: inlineSpans(in: lineRange, source: source, tokens: tokens))
        }

        let spans = inlineSpans(in: blockToken.contentRange, source: source, tokens: tokens)
        switch blockToken.token.kind {
        case let .heading(level):
            return .heading(level: level, spans: spans)
        case .unorderedList:
            return .unorderedItem(spans: spans)
        case .orderedList:
            let prefixLength = max(0, blockToken.contentRange.location - lineRange.location)
            let prefix = (line as NSString).substring(with: NSRange(location: 0, length: prefixLength))
            let number = Int(prefix.prefix { $0.isNumber }) ?? 1
            return .orderedItem(number: number, spans: spans)
        case let .task(checked):
            let checkboxRange = (line as NSString).range(of: checked ? "[x]" : "[ ]", options: .caseInsensitive)
            let checkboxOffset = checkboxRange.location == NSNotFound
                ? lineRange.location
                : lineRange.location + checkboxRange.location
            return .task(
                checked: checked,
                text: spans.map(spanText).joined(),
                sourceUTF16Offset: checkboxOffset
            )
        case .blockquote:
            return .blockquote(spans: spans)
        default:
            return .paragraph(spans: [.plain(line)])
        }
    }

    private func inlineSpans(
        in contentRange: NSRange,
        source: String,
        tokens: [(token: MarkdownToken, range: NSRange, contentRange: NSRange)]
    ) -> [MarkdownPreviewSpan] {
        let sourceNSString = source as NSString
        let inlineTokens = tokens
            .filter { item in
                item.range.location >= contentRange.location
                    && NSMaxRange(item.range) <= NSMaxRange(contentRange)
                    && isInlineKind(item.token.kind)
            }
            .sorted { $0.range.location < $1.range.location }

        var spans: [MarkdownPreviewSpan] = []
        var cursor = contentRange.location
        for item in inlineTokens where item.range.location >= cursor {
            appendPlain(
                NSRange(location: cursor, length: item.range.location - cursor),
                sourceNSString: sourceNSString,
                to: &spans
            )
            let content = sourceNSString.substring(with: item.contentRange)
            switch item.token.kind {
            case .bold: spans.append(.bold(content))
            case .italic: spans.append(.italic(content))
            case .strikethrough: spans.append(.strikethrough(content))
            case let .link(destination): spans.append(.link(label: content, destination: destination))
            case .inlineCode: spans.append(.inlineCode(content))
            default: break
            }
            cursor = NSMaxRange(item.range)
        }
        appendPlain(
            NSRange(location: cursor, length: max(0, NSMaxRange(contentRange) - cursor)),
            sourceNSString: sourceNSString,
            to: &spans
        )
        return spans
    }

    private func appendPlain(
        _ range: NSRange,
        sourceNSString: NSString,
        to spans: inout [MarkdownPreviewSpan]
    ) {
        guard range.length > 0 else { return }
        spans.append(.plain(sourceNSString.substring(with: range)))
    }

    private func isBlockKind(_ kind: MarkdownTokenKind) -> Bool {
        switch kind {
        case .heading, .unorderedList, .orderedList, .task, .blockquote: true
        default: false
        }
    }

    private func isInlineKind(_ kind: MarkdownTokenKind) -> Bool {
        switch kind {
        case .bold, .italic, .strikethrough, .link, .inlineCode: true
        default: false
        }
    }

    private func fenceLanguage(from openingLine: String) -> String? {
        let trimmed = openingLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return nil }
        let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        return language.isEmpty ? nil : language
    }

    private func droppingOneTrailingNewline(from text: String) -> String {
        if text.hasSuffix("\r\n") { return String(text.dropLast(2)) }
        if text.hasSuffix("\n") || text.hasSuffix("\r") { return String(text.dropLast()) }
        return text
    }

    private func visibleText(for block: MarkdownPreviewBlock) -> String {
        switch block {
        case let .heading(_, spans), let .paragraph(spans), let .unorderedItem(spans),
             let .orderedItem(_, spans), let .blockquote(spans):
            return spans.map(spanText).joined()
        case let .task(_, text, _): return text
        case let .codeBlock(_, code): return code
        case .blank: return ""
        }
    }

    private func spanText(_ span: MarkdownPreviewSpan) -> String {
        switch span {
        case let .plain(text), let .bold(text), let .italic(text),
             let .strikethrough(text), let .inlineCode(text):
            return text
        case let .link(label, _):
            return label
        }
    }
}
