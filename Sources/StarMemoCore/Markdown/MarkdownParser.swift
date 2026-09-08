import Foundation

public enum MarkdownTokenKind: Equatable, Sendable {
    case heading(level: Int)
    case bold
    case italic
    case strikethrough
    case unorderedList
    case orderedList
    case task(checked: Bool)
    case blockquote
    case link(destination: String)
    case inlineCode
    case fencedCode
}

public struct MarkdownToken: Equatable, Sendable {
    public let kind: MarkdownTokenKind
    public let range: Range<String.Index>
    public let contentRange: Range<String.Index>
    public let markerRanges: [Range<String.Index>]

    public init(
        kind: MarkdownTokenKind,
        range: Range<String.Index>,
        contentRange: Range<String.Index>,
        markerRanges: [Range<String.Index>]
    ) {
        self.kind = kind
        self.range = range
        self.contentRange = contentRange
        self.markerRanges = markerRanges
    }
}

public struct MarkdownBlock: Equatable, Sendable {
    public let range: Range<String.Index>
    public let isCodeBlock: Bool

    public init(range: Range<String.Index>, isCodeBlock: Bool) {
        self.range = range
        self.isCodeBlock = isCodeBlock
    }
}

public struct MarkdownParseResult: Equatable, Sendable {
    public let source: String
    public let blocks: [MarkdownBlock]
    public let tokens: [MarkdownToken]

    public init(source: String, blocks: [MarkdownBlock], tokens: [MarkdownToken]) {
        self.source = source
        self.blocks = blocks
        self.tokens = tokens
    }
}

public struct MarkdownParser: Sendable {
    private struct Patterns {
        let heading = try! NSRegularExpression(pattern: "^(#{1,6})[ \\t]+(.+)$")
        let task = try! NSRegularExpression(pattern: "^([ \\t]*[-+*][ \\t]+\\[([ xX])\\][ \\t]+)(.+)$")
        let unordered = try! NSRegularExpression(pattern: "^([ \\t]*[-+*][ \\t]+)(.+)$")
        let ordered = try! NSRegularExpression(pattern: "^([ \\t]*[0-9]+[.)][ \\t]+)(.+)$")
        let blockquote = try! NSRegularExpression(pattern: "^([ \\t]*>[ \\t]?)(.+)$")
        let inlineCode = try! NSRegularExpression(pattern: "`([^`\\n]+)`")
        let link = try! NSRegularExpression(pattern: "\\[([^]\\n]+)\\]\\(([^)\\n]+)\\)")
        let bold = try! NSRegularExpression(pattern: "\\*\\*([^*\\n]+)\\*\\*|__([^_\\n]+)__")
        let strikethrough = try! NSRegularExpression(pattern: "~~([^~\\n]+)~~")
        let italic = try! NSRegularExpression(pattern: "(?<!\\*)\\*([^*\\n]+)\\*(?!\\*)|(?<!_)_([^_\\n]+)_(?!_)")
    }

    public init() {}

    public func parse(_ source: String) -> MarkdownParseResult {
        guard !source.isEmpty else {
            return MarkdownParseResult(source: source, blocks: [], tokens: [])
        }

        let patterns = Patterns()
        let sourceNSString = source as NSString
        var tokens: [MarkdownToken] = []
        var blocks: [MarkdownBlock] = []
        var location = 0
        var openFence: (start: Int, contentStart: Int, marker: NSRange)?

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
            let lineRange = NSRange(location: lineStart, length: contentsEnd - lineStart)
            let line = sourceNSString.substring(with: lineRange)
            let leadingWhitespaceCount = line.prefix { $0 == " " || $0 == "\t" }.utf16.count
            let trimmed = String(line.dropFirst(leadingWhitespaceCount))

            if trimmed.hasPrefix("```") {
                let markerStart = lineStart + leadingWhitespaceCount
                let marker = NSRange(location: markerStart, length: contentsEnd - markerStart)
                if let fence = openFence {
                    let full = NSRange(location: fence.start, length: lineEnd - fence.start)
                    let content = NSRange(location: fence.contentStart, length: max(0, lineStart - fence.contentStart))
                    appendToken(
                        kind: .fencedCode,
                        fullRange: full,
                        contentRange: content,
                        markerRanges: [fence.marker, marker],
                        source: source,
                        to: &tokens
                    )
                    if let range = Range(full, in: source) {
                        blocks.append(MarkdownBlock(range: range, isCodeBlock: true))
                    }
                    openFence = nil
                } else {
                    openFence = (lineStart, lineEnd, marker)
                }
                location = lineEnd
                continue
            }

            if openFence != nil {
                location = lineEnd
                continue
            }

            if let range = Range(NSRange(location: lineStart, length: lineEnd - lineStart), in: source) {
                blocks.append(MarkdownBlock(range: range, isCodeBlock: false))
            }

            parseBlock(line, lineStart: lineStart, source: source, patterns: patterns, tokens: &tokens)
            if line.rangeOfCharacter(from: CharacterSet(charactersIn: "*_~[`") ) != nil {
                parseInline(line, lineStart: lineStart, source: source, patterns: patterns, tokens: &tokens)
            }
            location = lineEnd
        }

        if let fence = openFence {
            let full = NSRange(location: fence.start, length: sourceNSString.length - fence.start)
            if let range = Range(full, in: source) {
                blocks.append(MarkdownBlock(range: range, isCodeBlock: false))
            }
        }

        tokens.sort {
            source.distance(from: source.startIndex, to: $0.range.lowerBound)
                < source.distance(from: source.startIndex, to: $1.range.lowerBound)
        }
        return MarkdownParseResult(source: source, blocks: blocks, tokens: tokens)
    }

    private func parseBlock(
        _ line: String,
        lineStart: Int,
        source: String,
        patterns: Patterns,
        tokens: inout [MarkdownToken]
    ) {
        let full = NSRange(location: 0, length: (line as NSString).length)
        if let match = patterns.heading.firstMatch(in: line, range: full) {
            let marker = match.range(at: 1)
            appendLocalToken(
                kind: .heading(level: marker.length), match: match, contentGroup: 2,
                markerRanges: [marker], lineStart: lineStart, source: source, to: &tokens
            )
        } else if let match = patterns.task.firstMatch(in: line, range: full) {
            let checkedText = (line as NSString).substring(with: match.range(at: 2))
            appendLocalToken(
                kind: .task(checked: checkedText.lowercased() == "x"), match: match, contentGroup: 3,
                markerRanges: [match.range(at: 1)], lineStart: lineStart, source: source, to: &tokens
            )
        } else if let match = patterns.unordered.firstMatch(in: line, range: full) {
            appendLocalToken(
                kind: .unorderedList, match: match, contentGroup: 2,
                markerRanges: [match.range(at: 1)], lineStart: lineStart, source: source, to: &tokens
            )
        } else if let match = patterns.ordered.firstMatch(in: line, range: full) {
            appendLocalToken(
                kind: .orderedList, match: match, contentGroup: 2,
                markerRanges: [match.range(at: 1)], lineStart: lineStart, source: source, to: &tokens
            )
        } else if let match = patterns.blockquote.firstMatch(in: line, range: full) {
            appendLocalToken(
                kind: .blockquote, match: match, contentGroup: 2,
                markerRanges: [match.range(at: 1)], lineStart: lineStart, source: source, to: &tokens
            )
        }
    }

    private func parseInline(
        _ line: String,
        lineStart: Int,
        source: String,
        patterns: Patterns,
        tokens: inout [MarkdownToken]
    ) {
        let searchRange = NSRange(location: 0, length: (line as NSString).length)
        var occupied: [NSRange] = []

        func isFree(_ range: NSRange) -> Bool {
            !occupied.contains { NSIntersectionRange($0, range).length > 0 }
        }

        func addDelimited(_ regex: NSRegularExpression, kind: MarkdownTokenKind, delimiterLength: Int) {
            for match in regex.matches(in: line, range: searchRange) where isFree(match.range) {
                let contentGroup = match.range(at: 1).location != NSNotFound ? 1 : 2
                let content = match.range(at: contentGroup)
                let opening = NSRange(location: match.range.location, length: delimiterLength)
                let closing = NSRange(location: NSMaxRange(match.range) - delimiterLength, length: delimiterLength)
                appendLocalToken(
                    kind: kind, match: match, contentGroup: contentGroup,
                    markerRanges: [opening, closing], lineStart: lineStart, source: source, to: &tokens
                )
                occupied.append(match.range)
                _ = content
            }
        }

        addDelimited(patterns.inlineCode, kind: .inlineCode, delimiterLength: 1)

        for match in patterns.link.matches(in: line, range: searchRange) where isFree(match.range) {
            let label = match.range(at: 1)
            let destination = match.range(at: 2)
            let markerRanges = [
                NSRange(location: match.range.location, length: 1),
                NSRange(location: NSMaxRange(label), length: destination.location - NSMaxRange(label)),
                NSRange(location: NSMaxRange(match.range) - 1, length: 1),
            ]
            let destinationText = (line as NSString).substring(with: destination)
            appendLocalToken(
                kind: .link(destination: destinationText), match: match, contentGroup: 1,
                markerRanges: markerRanges, lineStart: lineStart, source: source, to: &tokens
            )
            occupied.append(match.range)
        }

        addDelimited(patterns.bold, kind: .bold, delimiterLength: 2)
        addDelimited(patterns.strikethrough, kind: .strikethrough, delimiterLength: 2)
        addDelimited(patterns.italic, kind: .italic, delimiterLength: 1)
    }

    private func appendLocalToken(
        kind: MarkdownTokenKind,
        match: NSTextCheckingResult,
        contentGroup: Int,
        markerRanges: [NSRange],
        lineStart: Int,
        source: String,
        to tokens: inout [MarkdownToken]
    ) {
        func global(_ range: NSRange) -> NSRange {
            NSRange(location: lineStart + range.location, length: range.length)
        }
        appendToken(
            kind: kind,
            fullRange: global(match.range),
            contentRange: global(match.range(at: contentGroup)),
            markerRanges: markerRanges.map(global),
            source: source,
            to: &tokens
        )
    }

    private func appendToken(
        kind: MarkdownTokenKind,
        fullRange: NSRange,
        contentRange: NSRange,
        markerRanges: [NSRange],
        source: String,
        to tokens: inout [MarkdownToken]
    ) {
        guard let range = Range(fullRange, in: source),
              let content = Range(contentRange, in: source)
        else {
            return
        }
        let markers = markerRanges.compactMap { Range($0, in: source) }
        tokens.append(MarkdownToken(kind: kind, range: range, contentRange: content, markerRanges: markers))
    }
}
