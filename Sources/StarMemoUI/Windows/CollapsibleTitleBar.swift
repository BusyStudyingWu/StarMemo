import Combine
import StarMemoCore
import SwiftUI

@MainActor
public final class TitleBarState: ObservableObject {
    @Published public private(set) var isPointerInsideTopEdge = false
    @Published public private(set) var isEditing = false
    @Published public private(set) var suppressHoverUntilExit = false
    @Published public private(set) var bodyInteractionRevision = 0

    public var isExpanded: Bool {
        isEditing || (isPointerInsideTopEdge && !suppressHoverUntilExit)
    }

    public init() {}

    public func pointerEnteredTopEdge() {
        isPointerInsideTopEdge = true
    }

    public func pointerExitedTopEdge() {
        isPointerInsideTopEdge = false
        suppressHoverUntilExit = false
    }

    public func beginEditing() {
        isEditing = true
    }

    public func endEditing() {
        isEditing = false
    }

    public func finishEditingAndSuppressHover() {
        let shouldSuppressHover = isPointerInsideTopEdge
        isEditing = false
        isPointerInsideTopEdge = false
        suppressHoverUntilExit = shouldSuppressHover
    }

    public func requestBodyInteraction() {
        guard isEditing else { return }
        bodyInteractionRevision += 1
    }
}

public struct CollapsibleTitleBar: View {
    public static let expandedHeight: CGFloat = 34
    public static let collapsedHeight: CGFloat = 6

    @ObservedObject private var titleBarState: TitleBarState
    @ObservedObject private var windowState: NoteWindowState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var titleIsFocused: Bool
    @State private var draftTitle: String

    private let title: String
    private let storageStatus: String
    private let storageDetail: String
    private let onRename: (String) -> Void
    private let onTogglePinned: () -> Void
    private let onAppearanceChange: (NoteAppearance) -> Void
    private let onClose: () -> Void

    public init(
        title: String,
        storageStatus: String = "",
        storageDetail: String = "",
        titleBarState: TitleBarState,
        windowState: NoteWindowState,
        onRename: @escaping (String) -> Void,
        onTogglePinned: @escaping () -> Void,
        onAppearanceChange: @escaping (NoteAppearance) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.title = title
        self.storageStatus = storageStatus
        self.storageDetail = storageDetail
        _draftTitle = State(initialValue: title)
        _titleBarState = ObservedObject(wrappedValue: titleBarState)
        _windowState = ObservedObject(wrappedValue: windowState)
        self.onRename = onRename
        self.onTogglePinned = onTogglePinned
        self.onAppearanceChange = onAppearanceChange
        self.onClose = onClose
    }

    public var body: some View {
        HStack(spacing: 10) {
            Group {
                if titleBarState.isEditing {
                    TextField("便笺标题", text: $draftTitle)
                        .textFieldStyle(.plain)
                        .focused($titleIsFocused)
                        .onAppear { titleIsFocused = true }
                        .onSubmit { finishEditing() }
                        .onExitCommand { cancelEditing() }
                        .titleBarControlRegion()
                } else {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .frame(minHeight: 24)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: beginEditing)
                        .titleBarControlRegion()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)

            Text(storageStatus)
                .font(.system(size: 10, weight: .medium))
                .fixedSize()
                .help(storageDetail)
                .accessibilityLabel("\(storageStatus)。\(storageDetail)")

            Button(action: onTogglePinned) {
                Image(systemName: windowState.isPinned ? "pin.fill" : "pin")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(windowState.isPinned ? "取消置顶" : "置顶便笺")
            .titleBarControlRegion()

            Menu {
                ForEach(NoteAppearance.allCases, id: \.self) { appearance in
                    Button(appearance.displayName) {
                        onAppearanceChange(appearance)
                    }
                }
            } label: {
                Image(systemName: "paintpalette")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("更改便笺颜色")
            .titleBarControlRegion()

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭便笺")
            .titleBarControlRegion()
        }
        .padding(.horizontal, 12)
        .frame(
            height: titleBarState.isExpanded ? Self.expandedHeight : Self.collapsedHeight,
            alignment: .top
        )
        .opacity(titleBarState.isExpanded ? 1 : 0.001)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlayPreferenceValue(TitleBarControlBounds.self) { anchors in
            GeometryReader { geometry in
                TitleBarDragRegion(excludedRects: titleBarState.isExpanded
                    ? anchors.map { geometry[$0] } : [])
            }
        }
        .contentShape(Rectangle())
        .onHover { isInside in
            if isInside {
                titleBarState.pointerEnteredTopEdge()
            } else {
                titleBarState.pointerExitedTopEdge()
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: titleBarState.isExpanded)
        .onChange(of: title) { _, newTitle in
            if !titleBarState.isEditing {
                draftTitle = newTitle
            }
        }
        .onChange(of: titleBarState.bodyInteractionRevision) { _, _ in
            guard titleBarState.isEditing else { return }
            finishEditing()
        }
        .onChange(of: titleBarState.isEditing) { _, editing in
            if editing {
                draftTitle = title
                titleIsFocused = true
            }
        }
    }

    private func beginEditing() {
        draftTitle = title
        titleBarState.beginEditing()
        titleIsFocused = true
    }

    private func finishEditing() {
        let candidate = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !candidate.isEmpty, candidate != title {
            onRename(candidate)
        }
        titleBarState.finishEditingAndSuppressHover()
        titleIsFocused = false
    }

    private func cancelEditing() {
        draftTitle = title
        titleBarState.finishEditingAndSuppressHover()
        titleIsFocused = false
    }
}

extension NoteAppearance {
    fileprivate var displayName: String {
        switch self {
        case .clear: "透明白"
        case .mistBlue: "雾蓝"
        case .lavender: "浅紫"
        case .warmYellow: "暖黄"
        case .graphite: "石墨黑"
        }
    }
}
