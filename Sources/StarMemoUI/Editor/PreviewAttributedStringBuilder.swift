import Foundation
import StarMemoCore
import SwiftUI

public struct PreviewAttributedStringBuilder: Sendable {
    public let fontSize: CGFloat

    public init(fontSize: CGFloat) {
        self.fontSize = fontSize
    }

    public func build(_ spans: [MarkdownPreviewSpan]) -> AttributedString {
        var result = AttributedString()
        for span in spans {
            var fragment = AttributedString(text(for: span))
            fragment.font = .system(size: fontSize)
            switch span {
            case .bold:
                fragment.inlinePresentationIntent = .stronglyEmphasized
            case .italic:
                fragment.inlinePresentationIntent = .emphasized
            case .strikethrough:
                fragment.inlinePresentationIntent = .strikethrough
            case let .link(_, destination):
                fragment.foregroundColor = .accentColor
                fragment.underlineStyle = .single
                fragment.link = URL(string: destination)
            case .inlineCode:
                fragment.inlinePresentationIntent = .code
                fragment.font = .system(size: fontSize * 0.92, design: .monospaced)
                fragment.backgroundColor = Color.primary.opacity(0.08)
            case .plain:
                break
            }
            result.append(fragment)
        }
        return result
    }

    private func text(for span: MarkdownPreviewSpan) -> String {
        switch span {
        case let .plain(text), let .bold(text), let .italic(text),
             let .strikethrough(text), let .inlineCode(text):
            return text
        case let .link(label, _):
            return label
        }
    }
}

public enum MarkdownPreviewMutation {
    public static func toggleTask(
        in source: String,
        checkboxUTF16Offset: Int
    ) -> String? {
        let sourceNSString = source as NSString
        guard checkboxUTF16Offset >= 0,
              checkboxUTF16Offset + 3 <= sourceNSString.length
        else {
            return nil
        }

        let marker = sourceNSString.substring(
            with: NSRange(location: checkboxUTF16Offset, length: 3)
        )
        guard marker == "[ ]" || marker.lowercased() == "[x]" else {
            return nil
        }

        let mutable = NSMutableString(string: source)
        mutable.replaceCharacters(
            in: NSRange(location: checkboxUTF16Offset + 1, length: 1),
            with: marker == "[ ]" ? "x" : " "
        )
        return mutable as String
    }
}
