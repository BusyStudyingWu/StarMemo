import Foundation

@MainActor
public final class StarMemoMarkdownCommandRelay {
    public static let request = Notification.Name("StarMemo.Markdown.commandRequest")

    private let commandBus: StarMemoMarkdownCommandBus
    private let isActive: () -> Bool
    nonisolated(unsafe) private var observer: NSObjectProtocol?

    public init(commandBus: StarMemoMarkdownCommandBus, isActive: @escaping () -> Bool) {
        self.commandBus = commandBus
        self.isActive = isActive
        observer = NotificationCenter.default.addObserver(
            forName: Self.request,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let command = note.object as? StarMemoMarkdownCommand else { return }
            MainActor.assumeIsolated {
                guard let self, self.isActive() else { return }
                self.commandBus.post(command)
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
