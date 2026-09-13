import Foundation
import StarMemoCore
import StarMemoTestSupport
import StarMemoUI

@MainActor
private final class CommandRouterSpy: AppCommandRouting {
    var commands: [String] = []
    var recentDocumentURLs: [URL] = []
    var quitResult = true
    var openError: Error?
    var hasOpenDocuments = false

    func commandNewNote() { commands.append("new") }
    func commandOpen(_ url: URL) throws {
        if let openError { throw openError }
        commands.append("open:\(url.lastPathComponent)")
    }
    func commandShowAll() { commands.append("show") }
    func commandHideAll() { commands.append("hide") }
    func commandSaveCurrent() async { commands.append("save") }
    func commandTogglePinnedCurrent() { commands.append("pin") }
    func commandRenameCurrent() { commands.append("rename") }
    func commandCloseCurrent() async { commands.append("close") }
    func commandFlushRecovery() { commands.append("flush") }
    func commandRequestQuit() async -> Bool {
        commands.append("quit")
        return quitResult
    }
}

@MainActor
private final class OpenChooserStub: OpenDocumentChoosing {
    var nextURL: URL?
    func chooseMarkdownFile() async -> URL? { nextURL }
}

@MainActor
let appControllerChecks: [Check] = [
    Check("app controller routes menu commands once") {
        let router = CommandRouterSpy()
        let chooser = OpenChooserStub()
        let defaults = UserDefaults(suiteName: "AppControllerChecks.\(UUID().uuidString)")!
        var terminationCount = 0
        let controller = AppController(
            router: router,
            settings: AppSettings(defaults: defaults),
            openChooser: chooser,
            terminate: { terminationCount += 1 }
        )
        let url = URL(fileURLWithPath: "/tmp/菜单测试.md")
        chooser.nextURL = url

        controller.newNote()
        await controller.openDocument()
        controller.openRecent(url)
        controller.showAll()
        controller.hideAll()
        await controller.saveCurrent()
        controller.togglePinnedCurrent()
        controller.renameCurrent()
        await controller.closeCurrent()
        controller.quit()

        try expect(router.commands == [
            "new", "open:菜单测试.md", "open:菜单测试.md",
            "show", "hide", "save", "pin", "rename", "close",
        ])
        try expect(terminationCount == 1)
    },
    Check("menu quit delegates directly to the system termination request") {
        let router = CommandRouterSpy()
        let defaults = UserDefaults(suiteName: "MenuQuit.\(UUID().uuidString)")!
        var terminationCount = 0
        let controller = AppController(
            router: router,
            settings: AppSettings(defaults: defaults),
            openChooser: OpenChooserStub(),
            terminate: { terminationCount += 1 }
        )

        controller.quit()

        try expect(router.commands.isEmpty)
        try expect(terminationCount == 1)
    },
    Check("cancelled system termination does not request termination recursively") {
        let router = CommandRouterSpy()
        router.quitResult = false
        let defaults = UserDefaults(suiteName: "SystemCancel.\(UUID().uuidString)")!
        var terminationCount = 0
        let controller = AppController(
            router: router,
            settings: AppSettings(defaults: defaults),
            openChooser: OpenChooserStub(),
            terminate: { terminationCount += 1 }
        )

        let allowed = await controller.requestSystemTermination()

        try expect(!allowed)
        try expect(router.commands == ["flush", "quit"])
        try expect(terminationCount == 0)
    },
    Check("app settings persist and clamp values") {
        let defaults = UserDefaults(suiteName: "AppSettingsChecks.\(UUID().uuidString)")!
        let settings = AppSettings(defaults: defaults)
        settings.windowOpacity = 0.2
        settings.editorFontSize = 99
        settings.defaultAppearance = .lavender
        settings.defaultPinned = true

        let restored = AppSettings(defaults: defaults)
        try expect(abs(restored.windowOpacity - 0.2) < 0.000001)
        try expect(restored.editorFontSize == 28)
        try expect(restored.defaultAppearance == .lavender)
        try expect(restored.defaultPinned)
    },
    Check("app settings migrate legacy opacity exactly once") {
        let suite = "TransparencyMigration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(0.65, forKey: "windowOpacity")
        let migrated = AppSettings(defaults: defaults)
        try expect(abs(migrated.windowOpacity - 0.82) < 0.000001, "Old opacity must migrate to its actual background alpha")
        migrated.windowOpacity = 0.5
        defaults.set(1.0, forKey: "windowOpacity")
        try expect(AppSettings(defaults: defaults).windowOpacity == 0.5, "Migration must not overwrite the new value")
        migrated.windowOpacity = -1
        try expect(migrated.windowOpacity == 0)
        migrated.windowOpacity = 2
        try expect(migrated.windowOpacity == 1)
    },
    Check("app controller reports the failed file path") {
        let router = CommandRouterSpy()
        router.openError = DocumentStoreError.invalidEncoding
        let defaults = UserDefaults(suiteName: "AppControllerError.\(UUID().uuidString)")!
        let controller = AppController(
            router: router,
            settings: AppSettings(defaults: defaults),
            openChooser: OpenChooserStub(),
            terminate: {}
        )
        let url = URL(fileURLWithPath: "/tmp/坏文件.md")

        controller.openRecent(url)

        try expect(controller.lastErrorMessage?.contains(url.path) == true)
        try expect(controller.lastErrorMessage?.contains("UTF-8") == true)
    },
    Check("system termination flushes and asks without terminating directly") {
        let router = CommandRouterSpy()
        let defaults = UserDefaults(suiteName: "SystemTermination.\(UUID().uuidString)")!
        var terminationCount = 0
        let controller = AppController(
            router: router,
            settings: AppSettings(defaults: defaults),
            openChooser: OpenChooserStub(),
            terminate: { terminationCount += 1 }
        )

        let allowed = await controller.requestSystemTermination()

        try expect(allowed)
        try expect(router.commands == ["flush", "quit"])
        try expect(terminationCount == 0)
    },
    Check("launch creates a note and Dock reopen shows existing notes") {
        let router = CommandRouterSpy()
        let defaults = UserDefaults(suiteName: "LaunchVisibility.\(UUID().uuidString)")!
        let controller = AppController(
            router: router,
            settings: AppSettings(defaults: defaults),
            openChooser: OpenChooserStub(),
            terminate: {}
        )

        controller.showInitialNoteIfNeeded()
        router.hasOpenDocuments = true
        controller.showInitialNoteIfNeeded()
        controller.handleReopen()

        try expect(router.commands == ["new", "show"])
    },
]
