import SwiftUI

public enum StatusBarPresentation {
    public static let noteSymbolName = "note"
    public static let starSymbolName = "star.fill"
    public static let visibleTitle: String? = nil
    public static let accessibilityLabel = "StarMemo"
}

public struct StatusBarIcon: View {
    public init() {}

    public var body: some View {
        ZStack {
            Image(systemName: StatusBarPresentation.noteSymbolName)
                .font(.system(size: 15, weight: .medium))
            Image(systemName: StatusBarPresentation.starSymbolName)
                .font(.system(size: 6, weight: .bold))
                .offset(y: 1)
        }
        .frame(width: 18, height: 18)
        .foregroundStyle(.primary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(StatusBarPresentation.accessibilityLabel)
    }
}
