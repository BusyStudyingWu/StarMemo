import Foundation
import StarMemoTestSupport
import StarMemoUI

@MainActor
private final class NotificationCounter {
    var value = 0
}

@MainActor
let markdownCommandRelayChecks: [Check] = [
    Check("only the active note relays a markdown command") {
        let activeBus = StarMemoMarkdownCommandBus(documentID: UUID())
        let inactiveBus = StarMemoMarkdownCommandBus(documentID: UUID())
        let active = StarMemoMarkdownCommandRelay(commandBus: activeBus, isActive: { true })
        let inactive = StarMemoMarkdownCommandRelay(commandBus: inactiveBus, isActive: { false })
        let activeCount = NotificationCounter()
        let inactiveCount = NotificationCounter()
        let center = NotificationCenter.default
        let activeName = try require(activeBus.engineBus.applyBoldRequest)
        let inactiveName = try require(inactiveBus.engineBus.applyBoldRequest)
        let activeObserver = center.addObserver(
            forName: activeName, object: nil, queue: .main
        ) { _ in MainActor.assumeIsolated { activeCount.value += 1 } }
        let inactiveObserver = center.addObserver(
            forName: inactiveName, object: nil, queue: .main
        ) { _ in MainActor.assumeIsolated { inactiveCount.value += 1 } }
        defer {
            center.removeObserver(activeObserver)
            center.removeObserver(inactiveObserver)
        }

        center.post(
            name: StarMemoMarkdownCommandRelay.request,
            object: StarMemoMarkdownCommand.bold
        )
        _ = active
        _ = inactive
        try expect(activeCount.value == 1)
        try expect(inactiveCount.value == 0)
    },
]
