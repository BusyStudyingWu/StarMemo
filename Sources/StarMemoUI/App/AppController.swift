import AppKit
import Combine
import Foundation
import StarMemoCore
import UniformTypeIdentifiers

@MainActor
public protocol AppCommandRouting: AnyObject {
    var recentDocumentURLs: [URL] { get }
    var hasOpenDocuments: Bool { get }
    func commandNewNote()
    func commandOpen(_ url: URL) throws
    func commandShowAll()
    func commandHideAll()
    func commandSaveCurrent() async
    func commandTogglePinnedCurrent()
    func commandRenameCurrent()
    func commandCloseCurrent() async
    func commandFlushRecovery()
    func commandRequestQuit() async -> Bool
}

@MainActor
public protocol OpenDocumentChoosing: AnyObject {
    func chooseMarkdownFile() async -> URL?
}

@MainActor
public final class AppKitOpenDocumentChooser: OpenDocumentChoosing {
    public init() {}

    public func chooseMarkdownFile() async -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "md")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }
}

@MainActor
public final class AppSettings: ObservableObject {
    private let defaults: UserDefaults

    @Published public var defaultAppearance: NoteAppearance {
        didSet { defaults.set(defaultAppearance.rawValue, forKey: "defaultAppearance") }
    }
    @Published public var editorFontSize: Double {
        didSet {
            let clamped = min(max(editorFontSize, 12), 28)
            if clamped != editorFontSize { editorFontSize = clamped; return }
            defaults.set(editorFontSize, forKey: "editorFontSize")
        }
    }
    @Published public var backgroundTransparency: Double {
        didSet {
            let clamped = backgroundTransparency.isFinite ? min(max(backgroundTransparency, 0), 1) : 0
            if clamped != backgroundTransparency { backgroundTransparency = clamped }
            defaults.set(clamped, forKey: "backgroundTransparency")
        }
    }
    /// Compatibility for window preferences; this is actual alpha, never a remapped slider value.
    public var windowOpacity: Double {
        get { 1 - backgroundTransparency }
        set { backgroundTransparency = 1 - newValue }
    }
    @Published public var defaultPinned: Bool {
        didSet { defaults.set(defaultPinned, forKey: "defaultPinned") }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaultAppearance = NoteAppearance(
            rawValue: defaults.string(forKey: "defaultAppearance") ?? ""
        ) ?? .clear
        editorFontSize = defaults.object(forKey: "editorFontSize") == nil
            ? 15
            : min(max(defaults.double(forKey: "editorFontSize"), 12), 28)
        if defaults.object(forKey: "backgroundTransparency") != nil {
            let stored = defaults.double(forKey: "backgroundTransparency")
            backgroundTransparency = stored.isFinite ? min(max(stored, 0), 1) : 0
        } else {
            // One-time migration only: preserve the old background's effective alpha.
            let stored = defaults.object(forKey: "windowOpacity") == nil ? 0.94 : defaults.double(forKey: "windowOpacity")
            let legacy = stored.isFinite ? min(max(stored, 0.65), 1) : 0.94
            let migrated = 1 - (0.82 + (legacy - 0.65) / 0.35 * 0.18)
            backgroundTransparency = migrated
            defaults.set(migrated, forKey: "backgroundTransparency")
        }
        defaultPinned = defaults.bool(forKey: "defaultPinned")
    }
}

@MainActor
public final class AppController: ObservableObject {
    public let settings: AppSettings
    @Published public private(set) var lastErrorMessage: String?

    private let router: any AppCommandRouting
    private let openChooser: any OpenDocumentChoosing
    private let terminate: @MainActor () -> Void
    private var recoveryErrorObserver: NSObjectProtocol?

    public var recentDocuments: [URL] { router.recentDocumentURLs }

    public init(
        router: any AppCommandRouting,
        settings: AppSettings,
        openChooser: any OpenDocumentChoosing,
        terminate: @escaping @MainActor () -> Void
    ) {
        self.router = router
        self.settings = settings
        self.openChooser = openChooser
        self.terminate = terminate
        recoveryErrorObserver = NotificationCenter.default.addObserver(
            forName: .starMemoRecoveryError,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let message = notification.userInfo?["message"] as? String
            MainActor.assumeIsolated {
                self?.lastErrorMessage = message
            }
        }
    }

    public static func live() -> AppController {
        let settings = AppSettings()
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let coordinator = NoteWindowCoordinator(
            recoveryDirectory: applicationSupport
                .appendingPathComponent("StarMemo")
                .appendingPathComponent("Recovery"),
            settings: settings
        )
        do {
            try coordinator.restoreDrafts()
        } catch {
            // A damaged recovery record must not prevent the menu bar app from starting.
        }
        let controller = AppController(
            router: coordinator,
            settings: settings,
            openChooser: AppKitOpenDocumentChooser(),
            terminate: { NSApplication.shared.terminate(nil) }
        )
        controller.showInitialNoteIfNeeded()
        return controller
    }

    public func newNote() {
        router.commandNewNote()
        objectWillChange.send()
    }

    public func showInitialNoteIfNeeded() {
        if !router.hasOpenDocuments { newNote() }
    }

    public func handleReopen() {
        if router.hasOpenDocuments { showAll() } else { newNote() }
    }

    public func openDocument() async {
        guard let url = await openChooser.chooseMarkdownFile() else { return }
        openRecent(url)
    }

    public func openRecent(_ url: URL) {
        do {
            try router.commandOpen(url)
            lastErrorMessage = nil
            objectWillChange.send()
        } catch {
            lastErrorMessage = "无法打开 \(url.path)：\(error.localizedDescription)"
        }
    }

    public func showAll() { router.commandShowAll() }
    public func hideAll() { router.commandHideAll() }
    public func saveCurrent() async { await router.commandSaveCurrent() }
    public func togglePinnedCurrent() { router.commandTogglePinnedCurrent() }
    public func renameCurrent() { router.commandRenameCurrent() }
    public func closeCurrent() async { await router.commandCloseCurrent() }

    public func quit() {
        terminate()
    }

    public func flushRecovery() {
        router.commandFlushRecovery()
    }

    public func requestSystemTermination() async -> Bool {
        router.commandFlushRecovery()
        return await router.commandRequestQuit()
    }
}
