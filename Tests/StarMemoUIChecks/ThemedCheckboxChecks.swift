import AppKit
import StarMemoCore
import StarMemoUI
import StarMemoTestSupport
import SwiftUI

@MainActor
private func checkboxEditor(in view: NSView) -> NSTextView? {
    (view as? NSTextView) ?? view.subviews.lazy.compactMap { checkboxEditor(in: $0) }.first
}

let themedCheckboxChecks: [Check] = [
    Check("themed checkbox pixels update live and remain independent of background alpha") {
        let document = MarkdownDocument(text: "- [ ] 未完成任务\n- [x] 已完成任务\n\n正文与撤销保持不变")
        let controller = NoteWindowController(
            document: document,
            preferences: NoteWindowPreferences(frame: CGRect(x: 150, y: 150, width: 350, height: 220), appearance: .clear, opacity: 0, isPinned: false),
            fontSize: 18, onCloseRequest: { _ in }, onRename: { _, _ in }, onPreferencesChange: { _, _ in }, onActivate: { _ in }
        )
        defer { controller.closeImmediately() }
        let window = try require(controller.window)
        window.colorSpace = .sRGB
        window.contentView = NSHostingView(rootView: NoteWindowView(
            document: document, state: controller.state, focusCoordinator: controller.markdownFocusCoordinator,
            onRename: { _ in }, onTogglePinned: {}, onAppearanceChange: { _ in }, onClose: {}, reduceTransparencyOverride: false
        ))
        controller.showWindow(nil)
        try await Task.sleep(for: .milliseconds(150))
        let content = try require(window.contentView)
        let editor = try require(checkboxEditor(in: content))
        _ = controller.markdownFocusCoordinator.handleMouseDown(windowPoint: CGPoint(x: 150, y: 60))
        editor.insertText("!", replacementRange: NSRange(location: editor.string.utf16.count, length: 0))
        try await Task.sleep(for: .milliseconds(100))
        editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
        let originalText = document.text
        let originalSelection = editor.selectedRange()
        let undo = try require(editor.undoManager)
        try expect(undo.canUndo)
        let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/verification/checkboxes-0.1.6")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let colors: [(NoteAppearance, [CGFloat])] = [
            (.clear, [0.87, 0.87, 0.85]), (.mistBlue, [0.77, 0.84, 0.88]),
            (.lavender, [0.84, 0.80, 0.89]), (.warmYellow, [0.89, 0.84, 0.68]),
            (.graphite, [0.72, 0.74, 0.76])
        ]
        for (appearance, expected) in colors {
            controller.setAppearance(appearance)
            for alpha in [0.0, 0.5, 1.0] {
                controller.setOpacity(alpha)
                try await Task.sleep(for: .milliseconds(150))
                content.layoutSubtreeIfNeeded()
                let bitmap = try require(content.bitmapImageRepForCachingDisplay(in: content.bounds))
                content.cacheDisplay(in: content.bounds, to: bitmap)
                let data = try require(bitmap.representation(using: .png, properties: [:]))
                try data.write(to: output.appendingPathComponent("\(appearance.rawValue)-\(Int(alpha * 100)).png"))
                var fillPixels = 0
                // The window renders in sRGB. Compare cached RGB samples directly:
                // converting colorAt's generic RGB wrapper applies a second transform.
                for y in 0..<bitmap.pixelsHigh {
                    for x in 0..<(bitmap.pixelsWide / 4) {
                        guard let color = bitmap.colorAt(x: x, y: y) else { continue }
                        if color.alphaComponent > 0.98 &&
                           abs(color.redComponent - expected[0]) < 0.015 &&
                           abs(color.greenComponent - expected[1]) < 0.015 &&
                           abs(color.blueComponent - expected[2]) < 0.015 { fillPixels += 1 }
                    }
                }
                try expect(fillPixels > 25, "Completed checkbox does not render \(appearance) fill at background alpha \(alpha); matches=\(fillPixels)")
                if alpha == 0 {
                    let rect = editor.firstRect(forCharacterRange: NSRange(location: 2, length: 3), actualRange: nil)
                    let point = content.convert(window.convertPoint(fromScreen: CGPoint(x: rect.midX, y: rect.midY)), from: nil)
                    let x = Int(point.x / content.bounds.width * CGFloat(bitmap.pixelsWide))
                    let topY = content.isFlipped ? point.y : content.bounds.height - point.y
                    let y = Int(topY / content.bounds.height * CGFloat(bitmap.pixelsHigh))
                    let center = try require(bitmap.colorAt(x: x, y: y))
                    try expect(center.alphaComponent < 0.01, "Unchecked center must have no fill")
                }
                try expect(checkboxEditor(in: content) === editor)
                try expect(editor.selectedRange() == originalSelection && document.text == originalText)
                try expect(undo.canUndo)
            }
        }
        undo.undo()
        try await Task.sleep(for: .milliseconds(100))
        try expect(!document.text.hasSuffix("!"), "Theme changes damaged native undo")
    },
]
