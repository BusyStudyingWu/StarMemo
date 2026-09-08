import Foundation
import StarMemoCore
import StarMemoTestSupport

private func text(_ range: Range<String.Index>, in source: String) -> String {
    String(source[range])
}

let markdownParserChecks: [Check] = [
    Check("markdown parser recognizes block syntax") {
        let source = "# 一级\n###### 六级\n> 引用\n- 列表\n1. 有序\n- [x] 完成"
        let tokens = MarkdownParser().parse(source).tokens
        try expect(tokens.contains { $0.kind == .heading(level: 1) })
        try expect(tokens.contains { $0.kind == .heading(level: 6) })
        try expect(tokens.contains { $0.kind == .blockquote })
        try expect(tokens.contains { $0.kind == .unorderedList })
        try expect(tokens.contains { $0.kind == .orderedList })
        try expect(tokens.contains { $0.kind == .task(checked: true) })
    },
    Check("markdown parser recognizes inline syntax and ranges") {
        let source = "**粗体** *斜体* ~~删除~~ [链接](https://example.com) `代码`"
        let tokens = MarkdownParser().parse(source).tokens
        let bold = try require(tokens.first { $0.kind == .bold }, "Missing bold token")
        try expect(text(bold.contentRange, in: source) == "粗体")
        try expect(bold.markerRanges.map { text($0, in: source) } == ["**", "**"])
        try expect(tokens.contains { $0.kind == .italic })
        try expect(tokens.contains { $0.kind == .strikethrough })
        try expect(tokens.contains { $0.kind == .link(destination: "https://example.com") })
        try expect(tokens.contains { $0.kind == .inlineCode })
    },
    Check("markdown parser protects fenced code contents") {
        let source = "```swift\n**not bold**\n```\n**bold**"
        let result = MarkdownParser().parse(source)
        try expect(result.tokens.filter { $0.kind == .fencedCode }.count == 1)
        let fence = try require(result.tokens.first { $0.kind == .fencedCode }, "Missing fence token")
        try expect(fence.markerRanges.map { text($0, in: source) } == ["```swift", "```"])
        try expect(result.tokens.filter { $0.kind == .bold }.count == 1)
        let bold = try require(result.tokens.first { $0.kind == .bold }, "Missing outer bold")
        try expect(text(bold.contentRange, in: source) == "bold")
    },
    Check("markdown parser ignores unclosed inline markers") {
        let source = "**未闭合 *也未闭合 [链接]("
        let result = MarkdownParser().parse(source)
        try expect(result.tokens.isEmpty)
    },
    Check("markdown parser treats an unclosed fence as plain text") {
        let result = MarkdownParser().parse("```swift\nlet value = 1")
        try expect(!result.tokens.contains { token in
            if case .fencedCode = token.kind { return true }
            return false
        })
    },
    Check("markdown parser handles ten thousand plain lines under one second") {
        let source = Array(repeating: "普通的一行文本", count: 10_000).joined(separator: "\n")
        let start = ContinuousClock.now
        let result = MarkdownParser().parse(source)
        let elapsed = start.duration(to: .now)
        try expect(result.source == source)
        try expect(elapsed < .seconds(1), "Parsing took \(elapsed)")
    },
]
