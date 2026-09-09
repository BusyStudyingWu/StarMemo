import AppKit
import SwiftUI

@MainActor
public protocol MarkdownEditorNativeFocusTarget: AnyObject {
    var isEditable: Bool { get set }
    var hasMarkedText: Bool { get }
    func contains(windowPoint: CGPoint) -> Bool
    func focusForBodyClick(windowPoint: CGPoint)
    func restyleForFocusChange()
}

@MainActor
public final class MarkdownEditorFocusCoordinator {
    /// Host-owned overlays may share the native editor's hit-test surface.
    public var excludesWindowPoint: (CGPoint) -> Bool = { _ in false }
    private let state: LivePreviewState
    private let onBodyInteraction: () -> Void
    private weak var target: MarkdownEditorNativeFocusTarget?
    private var pendingDeactivation = false
    nonisolated(unsafe) private var changeObservers: [NSObjectProtocol] = []

    public init(state: LivePreviewState, onBodyInteraction: @escaping () -> Void) {
        self.state = state
        self.onBodyInteraction = onBodyInteraction
        for name in [NSText.didChangeNotification, NSTextView.didChangeSelectionNotification] {
            changeObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                // Wait for AppKit and the Markdown delegate to finish committing.
                Task { @MainActor [weak self] in
                    guard let self, self.pendingDeactivation,
                          self.target?.hasMarkedText != true else { return }
                    self.deactivate()
                }
            })
        }
    }

    deinit { changeObservers.forEach(NotificationCenter.default.removeObserver) }

    public func attach(_ target: MarkdownEditorNativeFocusTarget) {
        self.target = target
    }

    public func deactivate() {
        guard target?.hasMarkedText != true else {
            pendingDeactivation = true
            return
        }
        pendingDeactivation = false
        state.applicationResignedActive()
        target?.isEditable = false
        target?.restyleForFocusChange()
    }

    @discardableResult
    public func handleMouseDown(windowPoint: CGPoint) -> Bool {
        guard !excludesWindowPoint(windowPoint),
              let target, target.contains(windowPoint: windowPoint) else { return false }
        pendingDeactivation = false
        target.isEditable = true
        state.bodyInteraction()
        onBodyInteraction()
        target.focusForBodyClick(windowPoint: windowPoint)
        return true
    }
}

struct MarkdownEditorFocusResolver: NSViewRepresentable {
    let coordinator: MarkdownEditorFocusCoordinator

    func makeNSView(context: Context) -> MarkdownEditorResolverView {
        MarkdownEditorResolverView(coordinator: coordinator)
    }

    func updateNSView(_ nsView: MarkdownEditorResolverView, context: Context) {
        nsView.coordinator = coordinator
        nsView.resolveEditor()
    }
}

final class MarkdownEditorResolverView: NSView {
    weak var coordinator: MarkdownEditorFocusCoordinator?
    private var target: NSTextViewFocusTarget?

    init(coordinator: MarkdownEditorFocusCoordinator) {
        self.coordinator = coordinator
        super.init(frame: .zero)
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        resolveEditor()
    }

    override func layout() {
        super.layout()
        resolveEditor()
    }

    func resolveEditor() {
        guard let window, let contentView = window.contentView else { return }
        let resolverRect = convert(bounds, to: nil)
        guard resolverRect.width > 0, resolverRect.height > 0 else { return }

        let candidates = contentView.descendants(of: NSScrollView.self).compactMap { scrollView -> (NSTextView, CGFloat)? in
            guard let documentView = scrollView.documentView,
                  let textView = documentView.firstDescendant(of: NSTextView.self) else {
                return nil
            }
            let candidateRect = scrollView.convert(scrollView.bounds, to: nil)
            let area = candidateRect.intersection(resolverRect).area
            return area > 0 ? (textView, area) : nil
        }
        guard let best = candidates.max(by: { $0.1 < $1.1 }),
              best.1 >= resolverRect.area * 0.8 else {
            return
        }
        if target?.textView === best.0 { return }
        let target = NSTextViewFocusTarget(textView: best.0)
        self.target = target
        coordinator?.attach(target)
    }
}

@MainActor
private final class NSTextViewFocusTarget: MarkdownEditorNativeFocusTarget {
    weak var textView: NSTextView?

    init(textView: NSTextView) {
        self.textView = textView
    }

    var isEditable: Bool {
        get { textView?.isEditable == true }
        set {
            textView?.isEditable = newValue
            textView?.isSelectable = newValue
        }
    }

    var hasMarkedText: Bool { textView?.hasMarkedText() == true }

    func contains(windowPoint: CGPoint) -> Bool {
        guard let textView, textView.window != nil,
              let viewport = textView.enclosingScrollView?.contentView else { return false }
        // Include blank space below short notes, but not scrollbars or content
        // scrolled outside the viewport. The host excludes its title overlay.
        return viewport.bounds.contains(viewport.convert(windowPoint, from: nil))
    }

    func restyleForFocusChange() {
        guard let textView else { return }
        NotificationCenter.default.post(
            name: NSTextView.didChangeSelectionNotification,
            object: textView
        )
    }

    func focusForBodyClick(windowPoint: CGPoint) {
        guard let textView, let window = textView.window else { return }
        let end = NSRange(location: textView.string.utf16.count, length: 0)
        if let layout = textView.textLayoutManager {
            layout.ensureLayout(for: layout.documentRange)
        }
        // AppKit's character hit testing does not reliably focus an empty
        // document or space beneath its final line. Keep text clicks native,
        // but explicitly map that blank area to EOF without adding newlines.
        let endRect = textView.firstRect(forCharacterRange: end, actualRange: nil)
        let screenPoint = window.convertPoint(toScreen: windowPoint)
        if textView.string.isEmpty || (endRect.height > 0 && screenPoint.y < endRect.minY) {
            textView.setSelectedRange(end)
        }
        window.makeFirstResponder(textView)
        // Removing the SwiftUI title field can clear firstResponder on the
        // next update. Restore it only if no other input control took focus.
        Task { @MainActor [weak textView, weak window] in
            await Task.yield()
            guard let textView, let window, textView.isEditable, window.isKeyWindow,
                  window.firstResponder == nil || window.firstResponder === window || window.firstResponder === window.contentView else { return }
            window.makeFirstResponder(textView)
        }
    }
}

private extension NSView {
    func descendants<T: NSView>(of type: T.Type) -> [T] {
        subviews.flatMap { view in
            (view as? T).map { [$0] } ?? [] + view.descendants(of: type)
        }
    }

    func firstDescendant<T: NSView>(of type: T.Type) -> T? {
        if let match = self as? T { return match }
        return subviews.lazy.compactMap { $0.firstDescendant(of: type) }.first
    }
}

private extension CGRect {
    var area: CGFloat { width * height }
}
