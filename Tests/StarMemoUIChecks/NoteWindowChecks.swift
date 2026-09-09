import AppKit
@testable import MarkdownEngine
import StarMemoCore
import StarMemoTestSupport
import StarMemoUI

let noteWindowChecks: [Check] = [
    Check("blank body click receives typing after rename or deactivation") {
        for source in ["", "short"] {
            for afterRename in [true, false] {
                let document = MarkdownDocument(text: source, suggestedTitle: "original")
                var renamed: String?
                let controller = NoteWindowController(
                    document: document, preferences: NoteWindowCoordinator.fallbackPreferences,
                    fontSize: 15, onCloseRequest: { _ in }, onRename: { _, name in renamed = name },
                    onPreferencesChange: { _, _ in }, onActivate: { _ in }
                )
                defer { controller.closeImmediately() }
                controller.showAndActivate()
                try await Task.sleep(for: .milliseconds(150))
                let window = try require(controller.window)
                let content = try require(window.contentView)
                let editor = try require(content.firstDescendantForCheck(of: NSTextView.self))
                editor.setSelectedRange(NSRange(location: 0, length: 0))
                if afterRename {
                    controller.beginRenaming()
                    try await Task.sleep(for: .milliseconds(150))
                    let field = try require(window.firstResponder as? NSTextView)
                    field.insertText("renamed", replacementRange: NSRange(location: 0, length: field.string.utf16.count))
                } else {
                    controller.markdownFocusCoordinator.deactivate()
                    window.makeFirstResponder(nil)
                }
                let viewport = try require(editor.enclosingScrollView?.contentView)
                let point = viewport.convert(CGPoint(x: viewport.bounds.midX, y: viewport.bounds.maxY - 60), to: nil)
                let down = try require(NSEvent.mouseEvent(
                    with: .leftMouseDown, location: point, modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                    context: nil, eventNumber: 1, clickCount: 1, pressure: 1
                ))
                let up = try require(NSEvent.mouseEvent(
                    with: .leftMouseUp, location: point, modifierFlags: [],
                    timestamp: down.timestamp + 0.01, windowNumber: window.windowNumber,
                    context: nil, eventNumber: 2, clickCount: 1, pressure: 0
                ))
                NSApplication.shared.postEvent(up, atStart: true)
                NSApplication.shared.sendEvent(down)
                try await Task.sleep(for: .milliseconds(150))
                try expect(window.firstResponder === editor, "Blank click did not focus body: source=\(source), rename=\(afterRename)")
                try expect(editor.selectedRange() == NSRange(location: source.utf16.count, length: 0), "Blank click must place caret at document end")
                let key = try require(NSEvent.keyEvent(
                    with: .keyDown, location: .zero, modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                    context: nil, characters: "x", charactersIgnoringModifiers: "x", isARepeat: false, keyCode: 7
                ))
                NSApplication.shared.sendEvent(key)
                try await Task.sleep(for: .milliseconds(150))
                try expect(document.text == source + "x", "Keyboard input was not inserted in body")
                if afterRename {
                    try expect(renamed == "renamed")
                    try expect(!controller.state.titleBar.isEditing && !controller.state.titleBar.isExpanded)
                }
            }
        }
    },
    Check("title drag surface excludes only name and controls") {
        let controller = NoteWindowController(
            document: MarkdownDocument(suggestedTitle: "名字"),
            preferences: NoteWindowPreferences(frame: CGRect(x: 100, y: 100, width: 500, height: 320), appearance: .clear, opacity: 1, isPinned: false),
            fontSize: 15, onCloseRequest: { _ in }, onRename: { _, _ in },
            onPreferencesChange: { _, _ in }, onActivate: { _ in }
        )
        defer { controller.closeImmediately() }
        controller.showAndActivate()
        controller.state.titleBar.pointerEnteredTopEdge()
        try await Task.sleep(for: .milliseconds(250))
        let content = try require(controller.window?.contentView)
        content.layoutSubtreeIfNeeded()
        @MainActor func findDragSurface(_ view: NSView) -> NSView? {
            if view.identifier?.rawValue == "StarMemoTitleDragRegion" { return view }
            return view.subviews.lazy.compactMap { findDragSurface($0) }.first
        }
        let surface = try require(findDragSurface(content), "Header has no dedicated blank-space drag surface")
        @MainActor func hit(_ x: CGFloat, _ y: CGFloat) -> NSView? {
            surface.hitTest(surface.convert(CGPoint(x: x, y: y), to: surface.superview))
        }
        try expect(hit(25, 12) == nil, "Name must remain clickable for renaming")
        try expect(hit(120, 12) === surface, "Blank space beside a short name must drag")
        try expect(hit(5, 12) === surface, "Leading header padding must drag")
        try expect(hit(250, 30) === surface, "Bottom header padding must drag")
        try expect(hit(250, 80) == nil, "Body must not drag")
        try expect(hit(480, 12) == nil, "Close button must retain its action")
        let blankPoint = surface.convert(CGPoint(x: 120, y: 12), to: content.superview)
        try expect(content.hitTest(blankPoint) === surface, "Actual window hit testing must reach the drag surface")
        let window = try require(controller.window)
        let namePoint = surface.convert(CGPoint(x: 25, y: 12), to: nil)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try require(NSEvent.mouseEvent(
                with: type, location: namePoint, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0
            ))
            window.sendEvent(event)
            try await Task.sleep(for: .milliseconds(60))
        }
        try await Task.sleep(for: .milliseconds(150))
        try expect(controller.state.titleBar.isEditing, "A single name click must still begin renaming")
        try expect(hit(25, 12) == nil, "Editing field must not be intercepted by dragging")
    },
    Check("production note theme snapshots keep foreground opaque") {
        let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build/verification/theme")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for appearance in NoteAppearance.allCases {
            let document = MarkdownDocument(text: "\n# 工作记录\n\n- [ ] 尚未完成的任务\n- [x] 已完成的任务\n\n正文 **加粗** 与 `代码`", suggestedTitle: "工作记录")
            let controller = NoteWindowController(
                document: document,
                preferences: NoteWindowPreferences(frame: CGRect(x: 100, y: 100, width: 380, height: 320), appearance: appearance, opacity: 0.65, isPinned: false),
                fontSize: 16, onCloseRequest: { _ in }, onRename: { _, _ in },
                onPreferencesChange: { _, _ in }, onActivate: { _ in }
            )
            defer { controller.closeImmediately() }
            controller.showWindow(nil)
            controller.state.titleBar.pointerEnteredTopEdge()
            try await Task.sleep(for: .milliseconds(200))
            let content = try require(controller.window?.contentView)
            content.layoutSubtreeIfNeeded()
            let editor = try require(content.firstDescendantForCheck(of: NSTextView.self))
            let bodyOffset = (editor.string as NSString).range(of: "正文").location
            let color = try require(editor.textStorage?.attribute(.foregroundColor, at: bodyOffset, effectiveRange: nil) as? NSColor)
            try expect(color.alphaComponent == 1)
            let bitmap = try require(content.bitmapImageRepForCachingDisplay(in: content.bounds))
            content.cacheDisplay(in: content.bounds, to: bitmap)
            let png = try require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: output.appendingPathComponent("\(appearance.rawValue).png"), options: .atomic)
        }
    },
    Check("rename command focuses the real title and body click commits and collapses") {
        let document = MarkdownDocument(suggestedTitle: "original name")
        var renamed: String?
        let controller = NoteWindowController(
            document: document, preferences: NoteWindowCoordinator.fallbackPreferences,
            fontSize: 15, onCloseRequest: { _ in }, onRename: { _, value in renamed = value },
            onPreferencesChange: { _, _ in }, onActivate: { _ in }
        )
        defer { controller.closeImmediately() }
        controller.beginRenaming()
        try await Task.sleep(for: .milliseconds(200))
        try expect(controller.state.titleBar.isEditing)
        let fieldEditor = try require(controller.window?.firstResponder as? NSTextView)
        try expect(fieldEditor.string == "original name", "Rename command did not focus title")
        fieldEditor.insertText("new name", replacementRange: NSRange(location: 0, length: fieldEditor.string.utf16.count))
        try await Task.sleep(for: .milliseconds(100))
        try expect(controller.markdownFocusCoordinator.handleMouseDown(windowPoint: CGPoint(x: 80, y: 100)))
        try await Task.sleep(for: .milliseconds(100))
        try expect(renamed == "new name")
        try expect(!controller.state.titleBar.isEditing && !controller.state.titleBar.isExpanded)
    },
    Check("production editor defers deactivation until marked Chinese text commits") {
        let document = MarkdownDocument(text: "# ")
        let controller = NoteWindowController(
            document: document, preferences: NoteWindowCoordinator.fallbackPreferences,
            fontSize: 15, onCloseRequest: { _ in }, onRename: { _, _ in },
            onPreferencesChange: { _, _ in }, onActivate: { _ in }
        )
        defer { controller.closeImmediately() }
        controller.window?.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(150))
        let editor = try require(controller.window?.contentView?.firstDescendantForCheck(of: NSTextView.self))
        _ = controller.markdownFocusCoordinator.handleMouseDown(windowPoint: CGPoint(x: 80, y: 100))
        editor.setSelectedRange(NSRange(location: 2, length: 0))
        editor.setMarkedText("中文", selectedRange: NSRange(location: 2, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        try expect(editor.hasMarkedText())
        controller.state.fontSize = 23
        controller.setAppearance(.graphite)
        try await Task.sleep(for: .milliseconds(100))
        try expect(editor.string == "# 中文" && editor.hasMarkedText())
        controller.markdownFocusCoordinator.deactivate()
        try expect(editor.isEditable, "Composition was disabled before commit")
        try expect(editor.string == "# 中文" && editor.hasMarkedText())
        editor.insertText("中文", replacementRange: editor.markedRange())
        editor.unmarkText()
        try await Task.sleep(for: .milliseconds(150))
        try expect(document.text == "# 中文", "Committed Chinese text was lost")
        try expect(!editor.isEditable)
        _ = controller.markdownFocusCoordinator.handleMouseDown(windowPoint: CGPoint(x: 80, y: 100))
        editor.insertText("继续", replacementRange: NSRange(location: 4, length: 0))
        try await Task.sleep(for: .milliseconds(150))
        try expect(document.text == "# 中文继续")
    },
    Check("settings font size updates an existing production editor") {
        let defaults = try require(UserDefaults(suiteName: "StarMemoFontCheck.\(UUID().uuidString)"))
        let settings = AppSettings(defaults: defaults)
        settings.editorFontSize = 15
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("StarMemoFontCheck-\(UUID().uuidString)")
        let coordinator = NoteWindowCoordinator(recoveryDirectory: root, settings: settings)
        let source = "font-check-\(UUID().uuidString)\n" + String(repeating: "plain text\n", count: 60)
        let document = coordinator.newDocument(text: source)
        document.markSaved(to: root.appendingPathComponent("not-written.md"), modificationDate: nil)
        try await Task.sleep(for: .milliseconds(150))
        let editor = try require(NSApplication.shared.windows.compactMap {
            $0.contentView?.firstDescendantForCheck(of: NSTextView.self)
        }.first { $0.string == source })
        let windowController = try require(editor.window?.windowController as? NoteWindowController)
        try expect(windowController.markdownFocusCoordinator.handleMouseDown(windowPoint: CGPoint(x: 100, y: 100)))
        editor.insertText("extra ", replacementRange: NSRange(location: 0, length: 0))
        try await Task.sleep(for: .milliseconds(100))
        let undoManager = try require(editor.undoManager)
        try expect(undoManager.canUndo, "Typing did not register undo")
        editor.setSelectedRange(NSRange(location: 3, length: 2))
        let scroll = try require(editor.enclosingScrollView)
        scroll.contentView.scroll(to: CGPoint(x: 0, y: 100))
        let originalY = scroll.contentView.bounds.origin.y
        settings.editorFontSize = 23
        try await Task.sleep(for: .milliseconds(150))
        let font = try require(editor.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        let passed = font.pointSize == 23
        let selectionPreserved = editor.selectedRange() == NSRange(location: 3, length: 2)
        let scrollPreserved = abs(scroll.contentView.bounds.origin.y - originalY) < 1
        let textPreserved = document.text == "extra " + source
        let undoName = undoManager.undoActionName
        undoManager.undo()
        try await Task.sleep(for: .milliseconds(100))
        let undoPreserved = document.text == source
        let undoDiagnostic = "editor=\(editor.string.prefix(12)), document=\(document.text.prefix(12)), editable=\(editor.isEditable)"
        let canRedo = undoManager.canRedo
        undoManager.redo()
        try await Task.sleep(for: .milliseconds(100))
        let redoPreserved = document.text == "extra " + source
        document.discardChanges()
        _ = await coordinator.requestClose(document.id)
        try expect(passed, "Existing editor still uses the old font size")
        try expect(selectionPreserved && scrollPreserved, "Selection=\(selectionPreserved), scroll=\(scrollPreserved)")
        try expect(textPreserved && undoPreserved, "Text=\(textPreserved), undo=\(undoPreserved), action=\(undoName), \(undoDiagnostic)")
        try expect(canRedo && redoPreserved, "Redo failed to restore the document text")
    },
    Check("real title region never requests a body rename commit") {
        let controller = NoteWindowController(
            document: MarkdownDocument(text: "body\n" + String(repeating: "line\n", count: 30)),
            preferences: NoteWindowCoordinator.fallbackPreferences,
            fontSize: 15, onCloseRequest: { _ in }, onRename: { _, _ in },
            onPreferencesChange: { _, _ in }, onActivate: { _ in }
        )
        defer { controller.closeImmediately() }
        controller.window?.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(150))
        controller.state.titleBar.beginEditing()
        controller.window?.contentView?.layoutSubtreeIfNeeded()
        let height = try require(controller.window?.contentView?.bounds.height)
        let width = try require(controller.window?.contentView?.bounds.width)
        for x in [CGFloat(30), width - 100, width - 60, width - 20] {
            try expect(!controller.markdownFocusCoordinator.handleMouseDown(windowPoint: CGPoint(x: x, y: height - 17)), "Title or controls were treated as body")
        }
        try expect(controller.state.titleBar.bodyInteractionRevision == 0)
        try expect(controller.markdownFocusCoordinator.handleMouseDown(windowPoint: CGPoint(x: 30, y: height - 100)), "Body was not accepted")
        try expect(controller.state.titleBar.bodyInteractionRevision == 1)
    },
    Check("blank space below a short note restores editing but its top strip does not") {
        let controller = NoteWindowController(
            document: MarkdownDocument(text: "short"), preferences: NoteWindowCoordinator.fallbackPreferences,
            fontSize: 15, onCloseRequest: { _ in }, onRename: { _, _ in },
            onPreferencesChange: { _, _ in }, onActivate: { _ in }
        )
        defer { controller.closeImmediately() }
        controller.window?.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(150))
        let height = try require(controller.window?.contentView?.bounds.height)
        try expect(!controller.markdownFocusCoordinator.handleMouseDown(windowPoint: CGPoint(x: 50, y: height - 2)))
        try expect(controller.markdownFocusCoordinator.handleMouseDown(windowPoint: CGPoint(x: 50, y: height / 2)))
        try expect(controller.state.livePreview.revealsActiveBlockMarkers)
    },
    Check("real editor refreshes theme across graphite and light without replacing the editor") {
        let source = "正文\n- [ ] 待办\n" + String(repeating: "滚动测试正文\n", count: 80)
        let document = MarkdownDocument(text: source)
        let controller = NoteWindowController(
            document: document,
            preferences: NoteWindowPreferences(frame: CGRect(x: 0, y: 0, width: 320, height: 360), appearance: .graphite, opacity: 1, isPinned: false),
            fontSize: 15, onCloseRequest: { _ in }, onRename: { _, _ in },
            onPreferencesChange: { _, _ in }, onActivate: { _ in }
        )
        defer { controller.closeImmediately() }
        controller.showWindow(nil)
        try await Task.sleep(for: .milliseconds(150))
        let view = try require(controller.window?.contentView?.firstDescendantForCheck(of: NSTextView.self))
        view.setSelectedRange(NSRange(location: 1, length: 0))
        let undoManager = try require(view.undoManager)
        undoManager.registerUndo(withTarget: view) { target in
            MainActor.assumeIsolated {
                target.setSelectedRange(NSRange(location: 0, length: 0))
            }
        }
        let scrollView = try require(view.enclosingScrollView)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 120))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        let scrollY = scrollView.contentView.bounds.origin.y
        try expect(scrollY > 0)
        for appearance: NoteAppearance in [.mistBlue, .graphite, .warmYellow] {
            controller.setAppearance(appearance)
            try await Task.sleep(for: .milliseconds(150))
            controller.window?.contentView?.layoutSubtreeIfNeeded()
            try expect(controller.window?.contentView?.firstDescendantForCheck(of: NSTextView.self) === view)
            let color = try require(view.textStorage?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor)
            let rgb = try require(color.usingColorSpace(.deviceRGB))
            try expect(appearance == .graphite ? rgb.redComponent > 0.9 : rgb.redComponent < 0.3, "Body color did not follow note appearance")
            try expect(view.selectedRange().location == 1)
            try expect(document.text == source)
            try expect(abs(scrollView.contentView.bounds.origin.y - scrollY) < 1)
            let nativeView = try require(view as? NativeTextView)
            try expect(nativeView.configuration.theme.bodyText.isEqual(color))
            try expect(nativeView.configuration.theme.taskCheckboxUncheckedStroke.isEqual(color.withAlphaComponent(0.62)))
            try expect((view.typingAttributes[.foregroundColor] as? NSColor)?.isEqual(color) == true)
            try expect(undoManager.canUndo)
        }
        undoManager.undo()
        try expect(view.selectedRange().location == 0)
    },
    Check("body interaction requests title commit only while editing") {
        let state = TitleBarState()
        try expect(state.bodyInteractionRevision == 0)
        state.requestBodyInteraction()
        try expect(state.bodyInteractionRevision == 0)
        state.beginEditing()
        state.requestBodyInteraction()
        try expect(state.bodyInteractionRevision == 1)
    },
    Check("note state changes presentation on window activity") {
        let preferences = NoteWindowPreferences(
            frame: CGRect(x: 0, y: 0, width: 360, height: 300),
            appearance: .clear,
            opacity: 1,
            isPinned: false
        )
        let state = NoteWindowState(preferences: preferences, documentID: UUID())
        state.windowResignedKey()
        try expect(state.editorPresentation.mode == .previewing)
        state.windowBecameKey()
        try expect(state.editorPresentation.mode == .previewing)
        state.requestBodyEditing()
        try expect(state.editorPresentation.mode == .editing)
    },
    Check("preview task mutation marks document dirty") {
        let document = MarkdownDocument(text: "- [ ] task", savedText: "- [ ] task")
        let preferences = NoteWindowPreferences(
            frame: CGRect(x: 0, y: 0, width: 360, height: 300),
            appearance: .clear,
            opacity: 1,
            isPinned: false
        )
        let state = NoteWindowState(preferences: preferences, documentID: UUID())
        state.togglePreviewTask(in: document, checkboxUTF16Offset: 2)
        try expect(document.text == "- [x] task")
        try expect(document.isDirty)
    },
    Check("title bar collapses after rename until pointer exits") {
        let state = TitleBarState()
        state.pointerEnteredTopEdge()
        state.beginEditing()
        state.finishEditingAndSuppressHover()
        try expect(!state.isExpanded)

        state.pointerEnteredTopEdge()
        try expect(!state.isExpanded, "Hover must stay suppressed until a real exit")
        state.pointerExitedTopEdge()
        state.pointerEnteredTopEdge()
        try expect(state.isExpanded)
    },
    Check("title bar uses compact single-line height") {
        try expect(CollapsibleTitleBar.expandedHeight == 34)
        try expect(CollapsibleTitleBar.collapsedHeight == 6)
    },
    Check("title editing stays expanded after pointer exits") {
        let state = TitleBarState()
        state.pointerEnteredTopEdge()
        state.beginEditing()
        state.pointerExitedTopEdge()
        try expect(state.isExpanded)
    },
    Check("note panel can become key for editing") {
        let panel = NotePanel(
            contentRect: CGRect(x: 0, y: 0, width: 320, height: 360),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        try expect(panel.canBecomeKey)
        try expect(panel.canBecomeMain)
    },
    Check("note window remains visible when another app becomes active") {
        let document = MarkdownDocument()
        let preferences = NoteWindowPreferences(
            frame: CGRect(x: 0, y: 0, width: 320, height: 360),
            appearance: .clear,
            opacity: 1,
            isPinned: false
        )
        let controller = NoteWindowController(
            document: document,
            preferences: preferences,
            fontSize: 15,
            onCloseRequest: { _ in },
            onRename: { _, _ in },
            onPreferencesChange: { _, _ in },
            onActivate: { _ in }
        )
        let window = try require(controller.window)

        try expect(!window.hidesOnDeactivate)
        controller.togglePinned()
        try expect(window.level == .floating)
        controller.togglePinned()
        try expect(window.level == .normal)
        controller.closeImmediately()
    },
    Check("application deactivation hides live preview markers for an open note") {
        let document = MarkdownDocument()
        let preferences = NoteWindowPreferences(
            frame: CGRect(x: 0, y: 0, width: 320, height: 360),
            appearance: .clear,
            opacity: 1,
            isPinned: false
        )
        let controller = NoteWindowController(
            document: document,
            preferences: preferences,
            fontSize: 15,
            onCloseRequest: { _ in },
            onRename: { _, _ in },
            onPreferencesChange: { _, _ in },
            onActivate: { _ in }
        )
        controller.state.livePreview.bodyInteraction()
        try expect(controller.state.livePreview.revealsActiveBlockMarkers)

        NotificationCenter.default.post(
            name: NSApplication.didResignActiveNotification,
            object: NSApplication.shared
        )

        try expect(!controller.state.livePreview.revealsActiveBlockMarkers)
        controller.closeImmediately()
    },
    Check("real note window resolves its Markdown body for first-click editing") {
        let document = MarkdownDocument()
        let preferences = NoteWindowPreferences(
            frame: CGRect(x: 0, y: 0, width: 320, height: 360),
            appearance: .clear,
            opacity: 1,
            isPinned: false
        )
        let controller = NoteWindowController(
            document: document,
            preferences: preferences,
            fontSize: 15,
            onCloseRequest: { _ in },
            onRename: { _, _ in },
            onPreferencesChange: { _, _ in },
            onActivate: { _ in }
        )
        controller.showWindow(nil)
        controller.window?.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let textView = try require(
            controller.window?.contentView?.firstDescendantForCheck(of: NSTextView.self)
        )
        let bodyPoint = textView.convert(
            CGPoint(x: textView.bounds.midX, y: textView.bounds.midY),
            to: nil
        )
        try expect(controller.markdownFocusCoordinator.handleMouseDown(windowPoint: bodyPoint), "Body focus missed: \(bodyPoint), text bounds \(textView.bounds), expanded \(controller.state.titleBar.isExpanded)")
        try expect(textView.isEditable)
        try expect(textView.isSelectable)
        controller.closeImmediately()
    },
    Check("real note window monitor forwards the first body mouse down") {
        let document = MarkdownDocument()
        let preferences = NoteWindowPreferences(
            frame: CGRect(x: 0, y: 0, width: 320, height: 360),
            appearance: .clear,
            opacity: 1,
            isPinned: false
        )
        let controller = NoteWindowController(
            document: document,
            preferences: preferences,
            fontSize: 15,
            onCloseRequest: { _ in },
            onRename: { _, _ in },
            onPreferencesChange: { _, _ in },
            onActivate: { _ in }
        )
        controller.showWindow(nil)
        controller.window?.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let window = try require(controller.window)
        let textView = try require(
            window.contentView?.firstDescendantForCheck(of: NSTextView.self)
        )
        let bodyPoint = textView.convert(
            CGPoint(x: textView.bounds.midX, y: textView.bounds.midY),
            to: nil
        )
        let event = try require(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: bodyPoint,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ))
        // NSTextView tracks a press synchronously until release in a real AppKit loop.
        let release = try require(NSEvent.mouseEvent(
            with: .leftMouseUp, location: bodyPoint, modifierFlags: [],
            timestamp: event.timestamp + 0.01, windowNumber: window.windowNumber,
            context: nil, eventNumber: 2, clickCount: 1, pressure: 0
        ))
        NSApplication.shared.postEvent(release, atStart: true)
        NSApplication.shared.sendEvent(event)

        try expect(controller.state.livePreview.revealsActiveBlockMarkers)
        try expect(textView.isEditable)
        controller.closeImmediately()
    },
    Check("real Markdown body renders inactive strikethrough markers") {
        let document = MarkdownDocument(text: "~~删除线~~")
        let preferences = NoteWindowPreferences(
            frame: CGRect(x: 0, y: 0, width: 320, height: 360),
            appearance: .clear,
            opacity: 1,
            isPinned: false
        )
        let controller = NoteWindowController(
            document: document,
            preferences: preferences,
            fontSize: 15,
            onCloseRequest: { _ in },
            onRename: { _, _ in },
            onPreferencesChange: { _, _ in },
            onActivate: { _ in }
        )
        controller.showWindow(nil)
        controller.window?.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let textView = try require(
            controller.window?.contentView?.firstDescendantForCheck(of: NSTextView.self)
        )
        let storage = try require(textView.textStorage)
        let markerFont = try require(
            storage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        )
        let strikeStyle = storage.attribute(
            .strikethroughStyle,
            at: 2,
            effectiveRange: nil
        ) as? Int
        try expect(markerFont.pointSize <= 0.2)
        try expect((strikeStyle ?? 0) != 0)
        controller.closeImmediately()
    },
    Check("real Markdown body toggles a rendered task checkbox") {
        let document = MarkdownDocument(text: "- [ ] 待办")
        let preferences = NoteWindowPreferences(
            frame: CGRect(x: 0, y: 0, width: 320, height: 360),
            appearance: .clear,
            opacity: 1,
            isPinned: false
        )
        let controller = NoteWindowController(
            document: document,
            preferences: preferences,
            fontSize: 15,
            onCloseRequest: { _ in },
            onRename: { _, _ in },
            onPreferencesChange: { _, _ in },
            onActivate: { _ in }
        )
        controller.showWindow(nil)
        controller.window?.contentView?.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        controller.window?.contentView?.layoutSubtreeIfNeeded()

        let window = try require(controller.window)
        let textView = try require(
            window.contentView?.firstDescendantForCheck(of: NSTextView.self)
        )
        let bodyPoint = textView.convert(
            CGPoint(x: textView.bounds.midX, y: textView.bounds.midY),
            to: nil
        )
        try expect(controller.markdownFocusCoordinator.handleMouseDown(windowPoint: bodyPoint), "Checkbox focus missed: \(bodyPoint), text bounds \(textView.bounds), expanded \(controller.state.titleBar.isExpanded)")
        let checkboxRect = textView.firstRect(
            forCharacterRange: NSRange(location: 2, length: 3),
            actualRange: nil
        )
        let clickPoint = window.convertPoint(fromScreen: CGPoint(
            x: checkboxRect.midX,
            y: checkboxRect.midY
        ))
        let event = try require(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: clickPoint,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 2,
            clickCount: 1,
            pressure: 1
        ))
        textView.mouseDown(with: event)
        try await Task.sleep(for: .milliseconds(50))

        try expect(document.text == "- [x] 待办")
        controller.closeImmediately()
    },
    Check("note window title bar expands and respects editing") {
        let state = TitleBarState()
        try expect(!state.isExpanded)
        state.pointerEnteredTopEdge()
        try expect(state.isExpanded)
        state.beginEditing()
        state.pointerExitedTopEdge()
        try expect(state.isExpanded, "Editing should keep the title bar open")
        state.endEditing()
        try expect(!state.isExpanded)
    },
    Check("note window state clamps opacity and toggles pin") {
        let preferences = NoteWindowPreferences(
            frame: CGRect(x: 0, y: 0, width: 360, height: 300),
            appearance: .lavender,
            opacity: 0.2,
            isPinned: false
        )
        let state = NoteWindowState(preferences: preferences, documentID: UUID())
        try expect(state.opacity == 0.65)
        state.togglePinned()
        try expect(state.isPinned)
        state.opacity = 2
        state.normalizeOpacity()
        try expect(state.opacity == 1)
    },
    Check("note window keeps visible frames and recenters offscreen frames") {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let visible = CGRect(x: 50, y: 60, width: 360, height: 300)
        try expect(NoteWindowController.constrainedFrame(visible, visibleFrames: [screen]) == visible)

        let offscreen = CGRect(x: 4000, y: 3000, width: 360, height: 300)
        let constrained = NoteWindowController.constrainedFrame(offscreen, visibleFrames: [screen])
        try expect(screen.contains(constrained))
        try expect(constrained.midX == screen.midX)
        try expect(constrained.midY == screen.midY)
    },
]

private extension NSView {
    func firstDescendantForCheck<T: NSView>(of type: T.Type) -> T? {
        if let match = self as? T { return match }
        return subviews.lazy.compactMap { $0.firstDescendantForCheck(of: type) }.first
    }
}
