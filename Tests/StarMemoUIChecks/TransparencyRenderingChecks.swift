import AppKit
import StarMemoCore
import StarMemoTestSupport
import StarMemoUI
import SwiftUI

@MainActor
private func transparencyBitmap(_ content: NSView, name: String) throws -> NSBitmapImageRep {
    content.layoutSubtreeIfNeeded()
    let bitmap = try require(content.bitmapImageRepForCachingDisplay(in: content.bounds))
    content.cacheDisplay(in: content.bounds, to: bitmap)
    let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/verification")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let data = try require(bitmap.representation(using: .png, properties: [:]))
    try data.write(to: directory.appendingPathComponent("transparency-0.1.5-\(name).png"))
    return bitmap
}

@MainActor
private func sliders(in view: NSView) -> [NSSlider] {
    (view as? NSSlider).map { [$0] } ?? view.subviews.flatMap { sliders(in: $0) }
}

let transparencyRenderingChecks: [Check] = [
    Check("settings has one global group and disables transparency only for system override") {
        let suite = "SettingsRendering.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        settings.windowOpacity = 0.5
        let window = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 480, height: 350), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        for reduced in [false, true, false] {
            let host = NSHostingView(rootView: SettingsView(settings: settings, reduceTransparencyOverride: reduced))
            window.contentView = host
            window.makeKeyAndOrderFront(nil)
            try await Task.sleep(for: .milliseconds(250))
            let controls = sliders(in: host)
            try expect(controls.count == 2, "Expected only transparency and font sliders, found \(controls.count)")
            try expect(controls.filter { !$0.isEnabled }.count == (reduced ? 1 : 0), "System override must disable only transparency")
            let transparencySlider = try require(controls.first { $0.maxValue == 1 })
            try expect(transparencySlider.numberOfTickMarks == 0, "A hundred ticks obscure the transparency track")
            if !reduced {
                transparencySlider.doubleValue = 0.65
                transparencySlider.sendAction(transparencySlider.action, to: transparencySlider.target)
                try await Task.sleep(for: .milliseconds(50))
                try expect(abs(settings.windowOpacity - 0.35) < 0.000001, "Native slider action did not update settings")
                settings.windowOpacity = 0.5
                try await Task.sleep(for: .milliseconds(50))
            }
            _ = try transparencyBitmap(host, name: "settings-\(reduced ? "reduced" : "normal")")
            try expect(settings.windowOpacity == 0.5, "System override changed the saved preference")
        }
    },
    Check("real transparency pixels follow alpha while body and task boxes stay visible") {
        let document = MarkdownDocument(text: "# 透明度测试\n\n正文保持清晰\n\n- [ ] 待办边框\n- [x] 已完成")
        let controller = NoteWindowController(
            document: document,
            preferences: NoteWindowPreferences(frame: CGRect(x: 160, y: 160, width: 380, height: 350), appearance: .mistBlue, opacity: 1, isPinned: false),
            fontSize: 18, onCloseRequest: { _ in }, onRename: { _, _ in }, onPreferencesChange: { _, _ in }, onActivate: { _ in }
        )
        defer { controller.closeImmediately() }
        let window = try require(controller.window)
        window.contentView = NSHostingView(rootView: NoteWindowView(
            document: document, state: controller.state, focusCoordinator: controller.markdownFocusCoordinator,
            onRename: { _ in }, onTogglePinned: {}, onAppearanceChange: { _ in }, onClose: {},
            reduceTransparencyOverride: false
        ))
        controller.showWindow(nil)
        for alpha in [1.0, 0.5, 0.0] {
            controller.setOpacity(alpha)
            try await Task.sleep(for: .milliseconds(200))
            let bitmap = try transparencyBitmap(try require(window.contentView), name: "\(Int((1 - alpha) * 100))")
            // Empty lower body, away from text, scrollbars and rounded corners.
            let background = try require(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh * 4 / 5))
            try expect(abs(background.alphaComponent - alpha) < 0.03, "Background pixel alpha \(background.alphaComponent) != \(alpha)")
            try expect(window.alphaValue == 1)
            if alpha == 0 {
                var opaqueInkPixels = 0
                for y in 50..<(bitmap.pixelsHigh / 2) {
                    for x in 30..<(bitmap.pixelsWide * 3 / 4) {
                        if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                           color.alphaComponent > 0.95, color.redComponent < 0.3 {
                            opaqueInkPixels += 1
                        }
                    }
                }
                try expect(opaqueInkPixels > 100, "Foreground faded together with the background")
            }
        }
        let originalAlpha = controller.state.opacity
        window.contentView = NSHostingView(rootView: NoteWindowView(
            document: document, state: controller.state, focusCoordinator: controller.markdownFocusCoordinator,
            onRename: { _ in }, onTogglePinned: {}, onAppearanceChange: { _ in }, onClose: {},
            reduceTransparencyOverride: true
        ))
        try await Task.sleep(for: .milliseconds(200))
        let reduced = try transparencyBitmap(try require(window.contentView), name: "reduced")
        let background = try require(reduced.colorAt(x: reduced.pixelsWide / 2, y: reduced.pixelsHigh * 4 / 5))
        try expect(background.alphaComponent == 1 && controller.state.opacity == originalAlpha)
    },
]
