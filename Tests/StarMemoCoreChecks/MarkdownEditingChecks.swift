import Foundation
import StarMemoCore
import StarMemoTestSupport

private func selection(_ location: Int, _ length: Int, in text: String) -> Range<String.Index> {
    Range(NSRange(location: location, length: length), in: text)!
}

private func selectedText(_ result: MarkdownEditResult) -> String {
    String(result.text[result.selection])
}

let markdownEditingChecks: [Check] = [
    Check("markdown editing wraps and unwraps inline styles") {
        let source = "hello"
        let cases: [(MarkdownEditingCommand, String)] = [
            (.bold, "**hello**"),
            (.italic, "*hello*"),
            (.strikethrough, "~~hello~~"),
            (.inlineCode, "`hello`"),
        ]
        for (command, expected) in cases {
            let wrapped = command.apply(to: source, selection: selection(0, 5, in: source))
            try expect(wrapped.text == expected)
            try expect(selectedText(wrapped) == "hello")
            let unwrapped = command.apply(to: wrapped.text, selection: wrapped.selection)
            try expect(unwrapped.text == source)
            try expect(selectedText(unwrapped) == "hello")
        }
    },
    Check("markdown editing places empty cursor between markers") {
        let result = MarkdownEditingCommand.bold.apply(
            to: "ab",
            selection: selection(1, 0, in: "ab")
        )
        try expect(result.text == "a****b")
        try expect(NSRange(result.selection, in: result.text) == NSRange(location: 3, length: 0))
    },
    Check("markdown editing link selects destination and unwraps") {
        let source = "官网"
        let linked = MarkdownEditingCommand.link.apply(
            to: source,
            selection: selection(0, 2, in: source)
        )
        try expect(linked.text == "[官网](https://)")
        try expect(selectedText(linked) == "https://")
        let labelRange = selection(1, 2, in: linked.text)
        let unwrapped = MarkdownEditingCommand.link.apply(to: linked.text, selection: labelRange)
        try expect(unwrapped.text == source)
        try expect(selectedText(unwrapped) == source)
    },
    Check("markdown editing continues and exits lists") {
        let unordered = try require(MarkdownEditingCommand.continuation(forLine: "- item"))
        try expect(unordered.insertion == "\n- ")
        let ordered = try require(MarkdownEditingCommand.continuation(forLine: "9. item"))
        try expect(ordered.insertion == "\n10. ")
        let task = try require(MarkdownEditingCommand.continuation(forLine: "- [x] done"))
        try expect(task.insertion == "\n- [ ] ")
        let exit = try require(MarkdownEditingCommand.continuation(forLine: "- "))
        try expect(exit.lineReplacement == "")
        try expect(exit.insertion == "\n")
        try expect(MarkdownEditingCommand.continuation(forLine: "plain") == nil)
    },
    Check("markdown editing toggles task without moving cursor") {
        let source = "- [ ] first\n- [x] second"
        let first = try require(MarkdownEditingCommand.toggleTask(
            in: source,
            at: source.index(source.startIndex, offsetBy: 7)
        ))
        try expect(first.text.hasPrefix("- [x] first"))
        try expect(NSRange(first.selection, in: first.text).location == 7)
        let secondIndex = first.text.index(first.text.startIndex, offsetBy: 18)
        let second = try require(MarkdownEditingCommand.toggleTask(in: first.text, at: secondIndex))
        try expect(second.text.hasSuffix("- [ ] second"))
    },
]
