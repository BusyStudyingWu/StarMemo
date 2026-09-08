import Foundation

public struct MarkdownEditResult: Equatable, Sendable {
    public let text: String
    public let selection: Range<String.Index>

    public init(text: String, selection: Range<String.Index>) {
        self.text = text
        self.selection = selection
    }
}

public struct MarkdownListContinuation: Equatable, Sendable {
    public let lineReplacement: String
    public let insertion: String

    public init(lineReplacement: String, insertion: String) {
        self.lineReplacement = lineReplacement
        self.insertion = insertion
    }
}

public enum MarkdownEditingCommand: Sendable {
    case bold
    case italic
    case strikethrough
    case link
    case inlineCode

    public func apply(
        to source: String,
        selection: Range<String.Index>
    ) -> MarkdownEditResult {
        let selectedRange = NSRange(selection, in: source)
        switch self {
        case .bold:
            return toggleDelimited("**", in: source, selection: selectedRange)
        case .italic:
            return toggleDelimited("*", in: source, selection: selectedRange)
        case .strikethrough:
            return toggleDelimited("~~", in: source, selection: selectedRange)
        case .inlineCode:
            return toggleDelimited("`", in: source, selection: selectedRange)
        case .link:
            return toggleLink(in: source, selection: selectedRange)
        }
    }

    public static func continuation(forLine line: String) -> MarkdownListContinuation? {
        let fullRange = NSRange(location: 0, length: (line as NSString).length)
        let task = try! NSRegularExpression(
            pattern: "^([ \\t]*[-+*][ \\t]+\\[[ xX]\\][ \\t]*)(.*)$"
        )
        if let match = task.firstMatch(in: line, range: fullRange) {
            let content = (line as NSString).substring(with: match.range(at: 2))
            guard !content.trimmingCharacters(in: .whitespaces).isEmpty else {
                return MarkdownListContinuation(lineReplacement: "", insertion: "\n")
            }
            let prefix = (line as NSString).substring(with: match.range(at: 1))
            let basePrefix = prefix.replacingOccurrences(
                of: "\\[[xX]\\]",
                with: "[ ]",
                options: .regularExpression
            )
            return MarkdownListContinuation(lineReplacement: line, insertion: "\n\(basePrefix)")
        }

        let unordered = try! NSRegularExpression(pattern: "^([ \\t]*[-+*][ \\t]+)(.*)$")
        if let match = unordered.firstMatch(in: line, range: fullRange) {
            let content = (line as NSString).substring(with: match.range(at: 2))
            guard !content.trimmingCharacters(in: .whitespaces).isEmpty else {
                return MarkdownListContinuation(lineReplacement: "", insertion: "\n")
            }
            let prefix = (line as NSString).substring(with: match.range(at: 1))
            return MarkdownListContinuation(lineReplacement: line, insertion: "\n\(prefix)")
        }

        let ordered = try! NSRegularExpression(
            pattern: "^([ \\t]*)([0-9]+)([.)])([ \\t]+)(.*)$"
        )
        if let match = ordered.firstMatch(in: line, range: fullRange) {
            let content = (line as NSString).substring(with: match.range(at: 5))
            guard !content.trimmingCharacters(in: .whitespaces).isEmpty else {
                return MarkdownListContinuation(lineReplacement: "", insertion: "\n")
            }
            let indent = (line as NSString).substring(with: match.range(at: 1))
            let numberText = (line as NSString).substring(with: match.range(at: 2))
            let separator = (line as NSString).substring(with: match.range(at: 3))
            let spacing = (line as NSString).substring(with: match.range(at: 4))
            let nextNumber = (Int(numberText) ?? 0) + 1
            return MarkdownListContinuation(
                lineReplacement: line,
                insertion: "\n\(indent)\(nextNumber)\(separator)\(spacing)"
            )
        }
        return nil
    }

    public static func toggleTask(
        in source: String,
        at index: String.Index
    ) -> MarkdownEditResult? {
        let cursor = NSRange(index..<index, in: source).location
        let nsSource = source as NSString
        var lineStart = 0
        var lineEnd = 0
        var contentsEnd = 0
        nsSource.getLineStart(
            &lineStart,
            end: &lineEnd,
            contentsEnd: &contentsEnd,
            for: NSRange(location: cursor, length: 0)
        )
        let lineRange = NSRange(location: lineStart, length: contentsEnd - lineStart)
        let line = nsSource.substring(with: lineRange)
        let regex = try! NSRegularExpression(pattern: "^[ \\t]*[-+*][ \\t]+\\[([ xX])\\]")
        guard let match = regex.firstMatch(
            in: line,
            range: NSRange(location: 0, length: (line as NSString).length)
        ) else {
            return nil
        }

        let stateRange = match.range(at: 1)
        let state = (line as NSString).substring(with: stateRange)
        let mutable = NSMutableString(string: source)
        mutable.replaceCharacters(
            in: NSRange(location: lineStart + stateRange.location, length: stateRange.length),
            with: state.lowercased() == "x" ? " " : "x"
        )
        return makeResult(text: mutable as String, selection: NSRange(location: cursor, length: 0))
    }

    private func toggleDelimited(
        _ delimiter: String,
        in source: String,
        selection: NSRange
    ) -> MarkdownEditResult {
        let nsSource = source as NSString
        let delimiterLength = (delimiter as NSString).length
        let prefixRange = NSRange(
            location: selection.location - delimiterLength,
            length: delimiterLength
        )
        let suffixRange = NSRange(location: NSMaxRange(selection), length: delimiterLength)
        let hasPrefix = prefixRange.location >= 0
            && NSMaxRange(prefixRange) <= nsSource.length
            && nsSource.substring(with: prefixRange) == delimiter
        let hasSuffix = NSMaxRange(suffixRange) <= nsSource.length
            && nsSource.substring(with: suffixRange) == delimiter
        let mutable = NSMutableString(string: source)

        if hasPrefix && hasSuffix {
            mutable.deleteCharacters(in: suffixRange)
            mutable.deleteCharacters(in: prefixRange)
            return makeResult(
                text: mutable as String,
                selection: NSRange(
                    location: selection.location - delimiterLength,
                    length: selection.length
                )
            )
        }

        mutable.insert(delimiter, at: NSMaxRange(selection))
        mutable.insert(delimiter, at: selection.location)
        return makeResult(
            text: mutable as String,
            selection: NSRange(
                location: selection.location + delimiterLength,
                length: selection.length
            )
        )
    }

    private func toggleLink(in source: String, selection: NSRange) -> MarkdownEditResult {
        let nsSource = source as NSString
        let prefixLocation = selection.location - 1
        let suffixLocation = NSMaxRange(selection)
        if prefixLocation >= 0,
           nsSource.substring(with: NSRange(location: prefixLocation, length: 1)) == "[",
           suffixLocation + 2 <= nsSource.length,
           nsSource.substring(with: NSRange(location: suffixLocation, length: 2)) == "](" {
            let searchRange = NSRange(
                location: suffixLocation + 2,
                length: nsSource.length - suffixLocation - 2
            )
            let closing = nsSource.range(of: ")", options: [], range: searchRange)
            if closing.location != NSNotFound {
                let mutable = NSMutableString(string: source)
                mutable.deleteCharacters(
                    in: NSRange(location: suffixLocation, length: NSMaxRange(closing) - suffixLocation)
                )
                mutable.deleteCharacters(in: NSRange(location: prefixLocation, length: 1))
                return makeResult(
                    text: mutable as String,
                    selection: NSRange(location: prefixLocation, length: selection.length)
                )
            }
        }

        let destination = "https://"
        let mutable = NSMutableString(string: source)
        mutable.insert("](\(destination))", at: NSMaxRange(selection))
        mutable.insert("[", at: selection.location)
        return makeResult(
            text: mutable as String,
            selection: NSRange(
                location: selection.location + selection.length + 3,
                length: (destination as NSString).length
            )
        )
    }

    private static func makeResult(text: String, selection: NSRange) -> MarkdownEditResult {
        let range = Range(selection, in: text) ?? text.endIndex..<text.endIndex
        return MarkdownEditResult(text: text, selection: range)
    }

    private func makeResult(text: String, selection: NSRange) -> MarkdownEditResult {
        Self.makeResult(text: text, selection: selection)
    }
}
