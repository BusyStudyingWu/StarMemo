import StarMemoCore
import SwiftUI

public struct MarkdownPreviewView: View {
    private let document: MarkdownPreviewDocument
    private let fontSize: CGFloat
    private let initialAnchor: Int?
    private let onToggleTask: (Int) -> Void
    private let onRequestEditing: () -> Void

    public init(
        source: String,
        fontSize: CGFloat,
        initialAnchor: Int? = nil,
        onToggleTask: @escaping (Int) -> Void,
        onRequestEditing: @escaping () -> Void
    ) {
        document = MarkdownPreviewBuilder().build(source)
        self.fontSize = fontSize
        self.initialAnchor = initialAnchor
        self.onToggleTask = onToggleTask
        self.onRequestEditing = onRequestEditing
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(document.blocks.enumerated()), id: \.offset) { index, block in
                        blockView(block)
                            .id(index)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 16)
            }
            .onAppear {
                guard let initialAnchor else { return }
                proxy.scrollTo(nearestBlockIndex(for: initialAnchor), anchor: .top)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownPreviewBlock) -> some View {
        switch block {
        case let .heading(level, spans):
            Text(attributed(spans, size: headingSize(level)))
                .fontWeight(.semibold)
                .textSelection(.enabled)
                .onTapGesture(perform: onRequestEditing)

        case let .paragraph(spans):
            Text(attributed(spans))
                .textSelection(.enabled)
                .onTapGesture(perform: onRequestEditing)

        case let .unorderedItem(spans):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                Text(attributed(spans)).textSelection(.enabled)
            }
            .onTapGesture(perform: onRequestEditing)

        case let .orderedItem(number, spans):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(number).")
                    .foregroundStyle(.secondary)
                Text(attributed(spans)).textSelection(.enabled)
            }
            .onTapGesture(perform: onRequestEditing)

        case let .task(checked, text, sourceUTF16Offset):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Button {
                    onToggleTask(sourceUTF16Offset)
                } label: {
                    Image(systemName: checked ? "checkmark.square.fill" : "square")
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(checked ? "标记为未完成" : "标记为已完成")

                Text(text)
                    .font(.system(size: fontSize))
                    .strikethrough(checked, color: .secondary)
                    .foregroundStyle(checked ? .secondary : .primary)
                    .textSelection(.enabled)
                    .onTapGesture(perform: onRequestEditing)
            }

        case let .blockquote(spans):
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.secondary.opacity(0.55))
                    .frame(width: 3)
                Text(attributed(spans))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .fixedSize(horizontal: false, vertical: true)
            .onTapGesture(perform: onRequestEditing)

        case let .codeBlock(language, code):
            VStack(alignment: .leading, spacing: 0) {
                if let language {
                    Text(language.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 3)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(code)
                        .font(.system(size: fontSize * 0.92, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(12)
                }
            }
            .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            .onTapGesture(perform: onRequestEditing)

        case .blank:
            Color.clear.frame(height: 4)
        }
    }

    private func attributed(_ spans: [MarkdownPreviewSpan], size: CGFloat? = nil) -> AttributedString {
        PreviewAttributedStringBuilder(fontSize: size ?? fontSize).build(spans)
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: fontSize * 1.65
        case 2: fontSize * 1.42
        case 3: fontSize * 1.25
        default: fontSize * 1.08
        }
    }

    private func nearestBlockIndex(for sourceOffset: Int) -> Int {
        guard !document.blocks.isEmpty else { return 0 }
        var consumed = 0
        for index in document.blocks.indices {
            let next = consumed + visibleLength(document.blocks[index]) + 1
            if sourceOffset < next { return index }
            consumed = next
        }
        return document.blocks.index(before: document.blocks.endIndex)
    }

    private func visibleLength(_ block: MarkdownPreviewBlock) -> Int {
        switch block {
        case let .heading(_, spans), let .paragraph(spans), let .unorderedItem(spans),
             let .orderedItem(_, spans), let .blockquote(spans):
            return spans.reduce(0) { $0 + spanText($1).utf16.count }
        case let .task(_, text, _): return text.utf16.count
        case let .codeBlock(_, code): return code.utf16.count
        case .blank: return 0
        }
    }

    private func spanText(_ span: MarkdownPreviewSpan) -> String {
        switch span {
        case let .plain(text), let .bold(text), let .italic(text),
             let .strikethrough(text), let .inlineCode(text): text
        case let .link(label, _): label
        }
    }
}
