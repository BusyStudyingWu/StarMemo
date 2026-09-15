import AppKit
import StarMemoUI
import SwiftUI

@MainActor
final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    weak var controller: AppController?

    func applicationDidResignActive(_ notification: Notification) {
        controller?.flushRecovery()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let controller else { return .terminateNow }
        Task { @MainActor in
            let shouldTerminate = await controller.requestSystemTermination()
            sender.reply(toApplicationShouldTerminate: shouldTerminate)
        }
        return .terminateLater
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        controller?.handleReopen()
        return true
    }
}

@main
@MainActor
struct StarMemoApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appDelegate
    @StateObject private var controller: AppController

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
        let liveController = AppController.live()
        _controller = StateObject(wrappedValue: liveController)
        appDelegate.controller = liveController
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(controller: controller)
        } label: {
            StatusBarIcon()
        }
        Settings {
            SettingsView(settings: controller.settings)
        }
        .commands {
            StarMemoAppCommands(controller: controller)
            MarkdownCommands()
            TextEditingCommands()
        }
    }
}
