import AppKit
import StarMemoCore
import SwiftUI

public struct MarkdownEditorView: NSViewRepresentable {
    @Binding private var text: String
    private let fontSize: CGFloat
    private let livePreviewState: LivePreviewState
    private let onCompositionStateChange: (Bool) -> Void
    private let onBodyInteraction: () -> Void
    private let scrollAnchor: Binding<Int?>

    public init(
        text: Binding<String>,
        fontSize: CGFloat,
        livePreviewState: LivePreviewState,
        onCompositionStateChange: @escaping (Bool) -> Void = { _ in },
        onBodyInteraction: @escaping () -> Void = {},
        scrollAnchor: Binding<Int?> = .constant(nil)
    ) {
        _text = text
        self.fontSize = fontSize
        self.livePreviewState = livePreviewState
        self.onCompositionStateChange = onCompositionStateChange
        self.onBodyInteraction = onBodyInteraction
        self.scrollAnchor = scrollAnchor
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public static func shouldRestyle(hasMarkedText: Bool) -> Bool {
        !hasMarkedText
    }

    public var currentMarkerVisibility: Bool {
        livePreviewState.revealsActiveBlockMarkers
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = MarkdownTextView()
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = context.coordinator
        textView.onBodyInteraction = { [weak coordinator = context.coordinator] in
            coordinator?.bodyInteraction()
        }
        textView.string = text
        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.observeScrolling(in: scrollView)
        context.coordinator.restyle()
        context.coordinator.applyScrollAnchorIfNeeded()
        DispatchQueue.main.async { [weak scrollView, weak textView] in
            guard let scrollView, let textView, scrollView.window?.isKeyWindow == true else { return }
            scrollView.window?.makeFirstResponder(textView)
        }
        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? MarkdownTextView else {
            return
        }
        if textView.string != text {
            let selection = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(NSIntersectionRange(selection, NSRange(location: 0, length: (text as NSString).length)))
        }
        context.coordinator.restyle()
        context.coordinator.applyScrollAnchorIfNeeded()
    }

    @MainActor
    public final class Coordinator: NSObject, NSTextViewDelegate {
        fileprivate var parent: MarkdownEditorView
        fileprivate weak var textView: MarkdownTextView?
        private weak var scrollView: NSScrollView?
        private var lastAppliedAnchor: Int?

        fileprivate init(parent: MarkdownEditorView) {
            self.parent = parent
            super.init()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(applicationDidResignActive(_:)),
                name: NSApplication.didResignActiveNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidResignKey(_:)),
                name: NSWindow.didResignKeyNotification,
                object: nil
            )
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView else {
                return
            }
            reportCompositionState()
            parent.text = textView.string
            NSObject.cancelPreviousPerformRequests(
                withTarget: self,
                selector: #selector(restyle),
                object: nil
            )
            perform(#selector(restyle), with: nil, afterDelay: 0.075)
        }

        public func textViewDidChangeSelection(_ notification: Notification) {
            reportCompositionState()
            restyle()
        }

        fileprivate func observeScrolling(in scrollView: NSScrollView) {
            self.scrollView = scrollView
            scrollView.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(scrollBoundsDidChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
        }

        fileprivate func applyScrollAnchorIfNeeded() {
            guard let textView,
                  let anchor = parent.scrollAnchor.wrappedValue,
                  anchor != lastAppliedAnchor
            else {
                return
            }
            let safeAnchor = min(max(anchor, 0), (textView.string as NSString).length)
            lastAppliedAnchor = safeAnchor
            DispatchQueue.main.async { [weak textView] in
                textView?.scrollRangeToVisible(NSRange(location: safeAnchor, length: 0))
            }
        }

        @objc private func scrollBoundsDidChange(_ notification: Notification) {
            guard let textView, let scrollView else { return }
            let point = textView.convert(scrollView.contentView.bounds.origin, from: scrollView.contentView)
            let offset = textView.characterIndexForInsertion(at: point)
            let result = MarkdownParser().parse(textView.string)
            let anchor = result.blocks
                .map { NSRange($0.range, in: textView.string) }
                .first { NSLocationInRange(offset, $0) || offset == NSMaxRange($0) }?
                .location ?? offset
            lastAppliedAnchor = anchor
            if parent.scrollAnchor.wrappedValue != anchor {
                parent.scrollAnchor.wrappedValue = anchor
            }
        }

        private func reportCompositionState() {
            guard let textView else { return }
            parent.onCompositionStateChange(textView.hasMarkedText())
        }

        fileprivate func bodyInteraction() {
            parent.onBodyInteraction()
            restyle()
        }

        public func applicationResignedActive() {
            parent.livePreviewState.applicationResignedActive()
            restyle()
        }

        @objc private func applicationDidResignActive(_ notification: Notification) {
            applicationResignedActive()
        }

        @objc private func windowDidResignKey(_ notification: Notification) {
            guard let window = notification.object as? NSWindow,
                  window === textView?.window
            else {
                return
            }
            parent.livePreviewState.windowResignedKey()
            restyle()
        }

        @objc fileprivate func restyle() {
            guard let textView, let storage = textView.textStorage else {
                return
            }
            guard MarkdownEditorView.shouldRestyle(hasMarkedText: textView.hasMarkedText()) else {
                return
            }
            let source = textView.string
            let result = MarkdownParser().parse(source)
            MarkdownTextStyler(fontSize: parent.fontSize).apply(
                source: source,
                activeBlock: MarkdownEditorView.activeBlock(
                    in: result,
                    selection: textView.selectedRange(),
                    source: source,
                    revealsMarkers: parent.currentMarkerVisibility
                ),
                parseResult: result,
                to: storage
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }

    public static func activeBlock(
        in result: MarkdownParseResult,
        selection: NSRange,
        source: String,
        revealsMarkers: Bool
    ) -> NSRange? {
        guard revealsMarkers else {
            return nil
        }
        return result.blocks
            .map { NSRange($0.range, in: source) }
            .first { block in
                selection.location >= block.location
                    && selection.location <= NSMaxRange(block)
            }
    }
}
