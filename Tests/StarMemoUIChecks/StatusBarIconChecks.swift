import StarMemoTestSupport
import StarMemoUI
import AppKit
import SwiftUI

let statusBarIconChecks: [Check] = [
    Check("status bar uses one note and star icon without a visible title") {
        try expect(StatusBarPresentation.visibleTitle == nil)
        try expect(StatusBarPresentation.accessibilityLabel == "StarMemo")
    },
    Check("status bar outline star is hollow and legible in light and dark") {
        for scheme in [ColorScheme.light, .dark] {
            for scale: CGFloat in [1, 2] {
                let renderer = ImageRenderer(content: StatusBarIcon().environment(\.colorScheme, scheme))
                renderer.scale = scale
                let bitmap = NSBitmapImageRep(cgImage: try require(renderer.cgImage))
                try expect(bitmap.pixelsWide == Int(18 * scale) && bitmap.pixelsHigh == Int(18 * scale))
                let center = try require(bitmap.colorAt(x: Int(9 * scale), y: Int(9 * scale)))
                try expect(center.alphaComponent < 0.1, "Star center must be hollow, not filled")
                var ink = 0
                for y in 0..<bitmap.pixelsHigh {
                    for x in 0..<bitmap.pixelsWide {
                        let color = try require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
                        if color.alphaComponent > 0.5 {
                            ink += 1
                            try expect(scheme == .light ? color.redComponent < 0.3 : color.redComponent > 0.7,
                                       "Icon must follow system light/dark foreground")
                        }
                    }
                }
                try expect(ink > Int(30 * scale * scale), "Icon strokes must remain visible")
                let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/verification")
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let filename = "status-icon-\(scheme == .light ? "light" : "dark")-\(Int(scale))x.png"
                try require(bitmap.representation(using: .png, properties: [:])).write(to: directory.appendingPathComponent(filename))
            }
        }
        let preview = ImageRenderer(content: HStack(spacing: 0) {
            StatusBarIcon().scaleEffect(6).frame(width: 180, height: 150)
                .environment(\.colorScheme, .light).background(Color.white)
            StatusBarIcon().scaleEffect(6).frame(width: 180, height: 150)
                .environment(\.colorScheme, .dark).background(Color.black)
        })
        preview.scale = 2
        let bitmap = NSBitmapImageRep(cgImage: try require(preview.cgImage))
        let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build/verification/status-icon-preview.png")
        try require(bitmap.representation(using: .png, properties: [:])).write(to: output)
    },
]
