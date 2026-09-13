import SwiftUI
import StarMemoCore

/// One alpha-bearing background layer. A second system material would change the
/// effective opacity and leave an opaque plate at the transparent endpoint.
public struct NoteBackgroundView: View {
    private let appearance: NoteAppearance
    private let opacity: Double
    private let reduceTransparency: Bool

    public init(appearance: NoteAppearance, opacity: Double, reduceTransparency: Bool) {
        self.appearance = appearance
        self.opacity = opacity
        self.reduceTransparency = reduceTransparency
    }

    public var body: some View {
        let palette = NoteColorPalette(appearance: appearance)
        Color(nsColor: palette.surface)
            .opacity(reduceTransparency ? 1 : palette.surfaceOpacity(for: opacity))
            .allowsHitTesting(false)
    }
}
