import AppKit
import Combine
import StarMemoCore
import SwiftUI

public final class NotePanel: NSPanel {
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }
}

@MainActor
public protocol NoteWindowHandling: AnyObject {
    var documentID: UUID { get }
    var isKeyWindow: Bool { get }
    func showAndActivate()
    func hide()
    func closeImmediately()
    func togglePinned()
    func beginRenaming()
}

@MainActor
public final class NoteWindowController: NSWindowController, NSWindowDelegate, NoteWindowHandling {
    public let noteDocument: MarkdownDocument
    public let state: NoteWindowState
    public let markdownFocusCoordinator: MarkdownEditorFocusCoordinator

    private let onCloseRequest: (UUID) -> Void
    private let onRename: (UUID, String) -> Void
    private let onPreferencesChange: (UUID, NoteWindowPreferences) -> Void
    private let onActivate: (UUID) -> Void
    nonisolated(unsafe) private var bodyMouseMonitor: Any?
    private var markdownCommandRelay: StarMemoMarkdownCommandRelay?
    private var fontSizeObserver: AnyCancellable?
    private var settingsObservers: Set<AnyCancellable> = []

    public init(
        document: MarkdownDocument,
        preferences: NoteWindowPreferences,
        fontSize: CGFloat,
        settings: AppSettings? = nil,
        onCloseRequest: @escaping (UUID) -> Void,
        onRename: @escaping (UUID, String) -> Void,
        onPreferencesChange: @escaping (UUID, NoteWindowPreferences) -> Void,
        onActivate: @escaping (UUID) -> Void
    ) {
        noteDocument = document
        state = NoteWindowState(preferences: preferences, documentID: document.id, fontSize: fontSize)
        markdownFocusCoordinator = MarkdownEditorFocusCoordinator(
            state: state.livePreview,
            onBodyInteraction: state.requestBodyInteraction
        )
        self.onCloseRequest = onCloseRequest
        self.onRename = onRename
        self.onPreferencesChange = onPreferencesChange
        self.onActivate = onActivate

        let visibleFrames = NSScreen.screens.map(\.visibleFrame)
        let frame = Self.constrainedFrame(preferences.frame, visibleFrames: visibleFrames)
        let panel = NotePanel(
            contentRect: frame,
            styleMask: [.borderless, .resizable, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init(window: panel)
        fontSizeObserver = settings?.$editorFontSize.sink { [weak state] size in
            state?.fontSize = CGFloat(size)
        }

        markdownFocusCoordinator.excludesWindowPoint = { [weak self] point in
            guard let self, let contentView = self.window?.contentView else { return true }
            let local = contentView.convert(point, from: nil)
            let topDistance = contentView.isFlipped
                ? local.y - contentView.bounds.minY
                : contentView.bounds.maxY - local.y
            let titleHeight = self.state.titleBar.isExpanded
                ? CollapsibleTitleBar.expandedHeight : CollapsibleTitleBar.collapsedHeight
            return topDistance >= 0 && topDistance <= titleHeight
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive(_:)),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )

        panel.delegate = self
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.appearance = NSAppearance(named: state.appearance == .graphite ? .darkAqua : .aqua)
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.minSize = NSSize(width: 260, height: 180)
        panel.level = state.isPinned ? .floating : .normal
        panel.collectionBehavior = [.fullScreenAuxiliary]

        panel.contentView = NSHostingView(rootView: NoteWindowView(
            document: document,
            state: state,
            focusCoordinator: markdownFocusCoordinator,
            onRename: { [weak self] title in
                guard let self else { return }
                self.onRename(self.noteDocument.id, title)
            },
            onTogglePinned: { [weak self] in
                self?.togglePinned()
            },
            onAppearanceChange: { [weak self] appearance in
                self?.setAppearance(appearance)
            },
            onClose: { [weak self] in
                guard let self else { return }
                self.onCloseRequest(self.noteDocument.id)
            }
        ))

        bodyMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) {
            [weak self] event in
            guard let self, event.window === self.window else { return event }
            if !NSApplication.shared.isActive {
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            self.markdownFocusCoordinator.handleMouseDown(windowPoint: event.locationInWindow)
            return event
        }
        markdownCommandRelay = StarMemoMarkdownCommandRelay(
            commandBus: state.markdownCommandBus,
            isActive: { [weak self] in
                guard let self else { return false }
                return self.window?.isKeyWindow == true
                    && self.state.livePreview.revealsActiveBlockMarkers
            }
        )
        // Initialization uses the supplied per-note preferences. Only subsequent
        // user changes to global settings should overwrite an existing note.
        if let settings {
            settings.$backgroundTransparency.dropFirst().sink { [weak self] value in
                self?.setOpacity(value.isFinite ? 1 - min(max(value, 0), 1) : 1)
            }.store(in: &settingsObservers)
            settings.$defaultAppearance.dropFirst().sink { [weak self] value in
                self?.setAppearance(value)
            }.store(in: &settingsObservers)
            settings.$defaultPinned.dropFirst().sink { [weak self] value in
                guard let self, self.state.isPinned != value else { return }
                self.togglePinned()
            }.store(in: &settingsObservers)
        }
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        if let bodyMouseMonitor {
            NSEvent.removeMonitor(bodyMouseMonitor)
        }
        NotificationCenter.default.removeObserver(self)
    }

    public var documentID: UUID { noteDocument.id }
    public var isKeyWindow: Bool { window?.isKeyWindow == true }

    public func showAndActivate() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    public func hide() {
        window?.orderOut(nil)
    }

    public func closeImmediately() {
        settingsObservers.removeAll()
        fontSizeObserver = nil
        markdownCommandRelay = nil
        if let bodyMouseMonitor {
            NSEvent.removeMonitor(bodyMouseMonitor)
            self.bodyMouseMonitor = nil
        }
        window?.delegate = nil
        window?.close()
    }

    public func togglePinned() {
        state.togglePinned()
        window?.level = state.isPinned ? .floating : .normal
        persistPreferences()
    }

    public func beginRenaming() {
        showAndActivate()
        state.titleBar.beginEditing()
    }

    public func setAppearance(_ appearance: NoteAppearance) {
        window?.appearance = NSAppearance(named: appearance == .graphite ? .darkAqua : .aqua)
        state.appearance = appearance
        persistPreferences()
    }

    public func setOpacity(_ opacity: Double) {
        state.opacity = opacity
        state.normalizeOpacity()
        persistPreferences()
    }

    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        onCloseRequest(noteDocument.id)
        return false
    }

    public func windowDidMove(_ notification: Notification) {
        persistPreferences()
    }

    public func windowDidResize(_ notification: Notification) {
        persistPreferences()
    }

    public func windowDidBecomeKey(_ notification: Notification) {
        state.windowBecameKey()
        onActivate(noteDocument.id)
    }

    public func windowDidResignKey(_ notification: Notification) {
        state.editorPresentation.windowResignedKey()
        markdownFocusCoordinator.deactivate()
        onActivate(noteDocument.id)
    }

    @objc private func applicationDidResignActive(_ notification: Notification) {
        markdownFocusCoordinator.deactivate()
    }

    public static func constrainedFrame(
        _ frame: CGRect,
        visibleFrames: [CGRect]
    ) -> CGRect {
        guard let primary = visibleFrames.first else {
            return frame
        }
        if visibleFrames.contains(where: { $0.intersects(frame) }) {
            return frame
        }
        let width = min(max(frame.width, 260), primary.width)
        let height = min(max(frame.height, 180), primary.height)
        return CGRect(
            x: primary.midX - width / 2,
            y: primary.midY - height / 2,
            width: width,
            height: height
        )
    }

    private func persistPreferences() {
        guard let window else {
            return
        }
        onPreferencesChange(
            noteDocument.id,
            NoteWindowPreferences(
                frame: window.frame,
                appearance: state.appearance,
                opacity: state.opacity,
                isPinned: state.isPinned
            )
        )
    }
}
