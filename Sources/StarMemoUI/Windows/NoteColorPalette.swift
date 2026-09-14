import AppKit
import StarMemoCore

/// The note's surface and ink are paired independently of the system theme.
public struct NoteColorPalette {
    public let surface: NSColor
    public let ink: NSColor
    public let checkedTaskFill: NSColor
    public let taskCheckmark = NSColor(srgbRed: 0.22, green: 0.25, blue: 0.27, alpha: 1)

    public init(appearance: NoteAppearance) {
        switch appearance {
        case .clear: surface = NSColor(srgbRed: 0.96, green: 0.96, blue: 0.95, alpha: 1)
        case .mistBlue: surface = NSColor(srgbRed: 0.86, green: 0.92, blue: 0.98, alpha: 1)
        case .lavender: surface = NSColor(srgbRed: 0.92, green: 0.88, blue: 0.98, alpha: 1)
        case .warmYellow: surface = NSColor(srgbRed: 1, green: 0.95, blue: 0.78, alpha: 1)
        case .graphite: surface = NSColor(srgbRed: 0.12, green: 0.13, blue: 0.15, alpha: 1)
        }
        ink = appearance == .graphite ? .white : NSColor(srgbRed: 0.16, green: 0.17, blue: 0.19, alpha: 1)
        switch appearance {
        case .clear: checkedTaskFill = NSColor(srgbRed: 0.87, green: 0.87, blue: 0.85, alpha: 1)
        case .mistBlue: checkedTaskFill = NSColor(srgbRed: 0.77, green: 0.84, blue: 0.88, alpha: 1)
        case .lavender: checkedTaskFill = NSColor(srgbRed: 0.84, green: 0.80, blue: 0.89, alpha: 1)
        case .warmYellow: checkedTaskFill = NSColor(srgbRed: 0.89, green: 0.84, blue: 0.68, alpha: 1)
        case .graphite: checkedTaskFill = NSColor(srgbRed: 0.72, green: 0.74, blue: 0.76, alpha: 1)
        }
    }

    public func surfaceOpacity(for windowOpacity: Double) -> Double {
        windowOpacity.isFinite ? min(max(windowOpacity, 0), 1) : 1
    }
}
