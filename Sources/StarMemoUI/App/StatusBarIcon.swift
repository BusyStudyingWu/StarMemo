import AppKit
import SwiftUI

public enum StatusBarPresentation {
    public static let visibleTitle: String? = nil
    public static let accessibilityLabel = "StarMemo"
}

public struct StatusBarIcon: View {
    public init() {}

    // MenuBarExtra extracts an Image from its label; it does not host an
    // arbitrary Shape view, even when that view renders correctly in previews.
    public var body: Image {
        Image(nsImage: Self.templateImage)
            .renderingMode(.template)
    }

    public static let templateImage: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.saveGState()
            defer { context.restoreGState() }
            context.addPath(FoldedStarNote().path(in: rect).cgPath)
            context.setStrokeColor(NSColor.black.cgColor)
            context.setLineWidth(1.25)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.strokePath()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = StatusBarPresentation.accessibilityLabel
        return image
    }()
}

/// A single 18-point silhouette: folded note and a large hollow star.
/// No font metrics or stacked SF Symbols, so spacing stays consistent.
private struct FoldedStarNote: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 4, y: 1.5))
        path.addLine(to: CGPoint(x: 14, y: 1.5))
        path.addQuadCurve(to: CGPoint(x: 16, y: 3.5), control: CGPoint(x: 16, y: 1.5))
        path.addLine(to: CGPoint(x: 16, y: 13.3))
        path.addLine(to: CGPoint(x: 12.8, y: 16.5))
        path.addLine(to: CGPoint(x: 4, y: 16.5))
        path.addQuadCurve(to: CGPoint(x: 2, y: 14.5), control: CGPoint(x: 2, y: 16.5))
        path.addLine(to: CGPoint(x: 2, y: 3.5))
        path.addQuadCurve(to: CGPoint(x: 4, y: 1.5), control: CGPoint(x: 2, y: 1.5))
        path.closeSubpath()
        path.move(to: CGPoint(x: 12.8, y: 16.5))
        path.addLine(to: CGPoint(x: 12.8, y: 14.8))
        path.addQuadCurve(to: CGPoint(x: 14.3, y: 13.3), control: CGPoint(x: 12.8, y: 13.3))
        path.addLine(to: CGPoint(x: 16, y: 13.3))

        path.move(to: CGPoint(x: 9, y: 4.4))
        path.addLine(to: CGPoint(x: 10.2, y: 6.9))
        path.addLine(to: CGPoint(x: 13, y: 7.3))
        path.addLine(to: CGPoint(x: 11, y: 9.2))
        path.addLine(to: CGPoint(x: 11.5, y: 12))
        path.addLine(to: CGPoint(x: 9, y: 10.65))
        path.addLine(to: CGPoint(x: 6.5, y: 12))
        path.addLine(to: CGPoint(x: 7, y: 9.2))
        path.addLine(to: CGPoint(x: 5, y: 7.3))
        path.addLine(to: CGPoint(x: 7.8, y: 6.9))
        path.closeSubpath()
        return path.applying(CGAffineTransform(scaleX: rect.width / 18, y: rect.height / 18)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY)))
    }
}
