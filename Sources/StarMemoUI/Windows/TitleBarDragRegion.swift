import AppKit
import SwiftUI

struct TitleBarControlBounds: PreferenceKey {
    static var defaultValue: [Anchor<CGRect>] { [] }

    static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    func titleBarControlRegion() -> some View {
        anchorPreference(key: TitleBarControlBounds.self, value: .bounds) { [$0] }
    }
}

/// Only blank header space participates in native window dragging. Layout anchors
/// keep the exclusions aligned with long names, resizing, and the title editor.
struct TitleBarDragRegion: NSViewRepresentable {
    var excludedRects: [CGRect]

    func makeNSView(context: Context) -> TitleBarDragView {
        let view = TitleBarDragView()
        view.identifier = NSUserInterfaceItemIdentifier("StarMemoTitleDragRegion")
        return view
    }

    func updateNSView(_ view: TitleBarDragView, context: Context) {
        view.excludedRects = excludedRects
    }
}

final class TitleBarDragView: NSView {
    var excludedRects: [CGRect] = []
    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard !isHidden, bounds.contains(local) else { return nil }
        if excludedRects.contains(where: { $0.contains(local) }) {
            return nil
        }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
