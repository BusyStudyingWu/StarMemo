import AppKit
import MarkdownEngine
import StarMemoCore
import StarMemoTestSupport
import StarMemoUI

@MainActor
let starMemoMarkdownConfigurationChecks: [Check] = [
    Check("note palette preserves body and checkbox contrast over extreme backdrops") {
        func luminance(_ rgb: [Double]) -> Double {
            let linear = rgb.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
            return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722
        }
        func contrast(_ a: [Double], _ b: [Double]) -> Double {
            let values = [luminance(a), luminance(b)]
            return (values.max()! + 0.05) / (values.min()! + 0.05)
        }
        for appearance in NoteAppearance.allCases {
            let palette = NoteColorPalette(appearance: appearance)
            let surface = try require(palette.surface.usingColorSpace(.sRGB))
            let ink = try require(palette.ink.usingColorSpace(.sRGB))
            let fg = [ink.redComponent, ink.greenComponent, ink.blueComponent].map(Double.init)
            for opacity in [0.65, 0.8, 1.0] {
                for backdrop in [0.0, 1.0] {
                    let alpha = palette.surfaceOpacity(for: opacity)
                    let bg = [surface.redComponent, surface.greenComponent, surface.blueComponent].map { Double($0) * alpha + backdrop * (1 - alpha) }
                    let stroke = zip(fg, bg).map { $0 * 0.62 + $1 * 0.38 }
                    try expect(contrast(fg, bg) >= 4.5, "Body contrast too low for \(appearance)")
                    try expect(contrast(stroke, bg) >= 3, "Checkbox contrast too low for \(appearance)")
                }
            }
        }
    },
    Check("pale notes keep dark ink in both system appearances") {
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            let appearance = try require(NSAppearance(named: name))
            var colors: [NSColor] = []
            appearance.performAsCurrentDrawingAppearance {
                for note in [NoteAppearance.clear, .mistBlue, .lavender, .warmYellow] {
                    colors.append(StarMemoMarkdownThemeFactory.make(
                        appearance: note, fontSize: 15,
                        bus: StarMemoMarkdownCommandBus(documentID: UUID()).engineBus
                    ).theme.bodyText)
                }
            }
            for color in colors {
                let rgb = try require(color.usingColorSpace(.deviceRGB))
                try expect(max(rgb.redComponent, rgb.greenComponent, rgb.blueComponent) < 0.3)
                try expect(rgb.alphaComponent == 1)
            }
        }
    },
    Check("markdown command buses are isolated per document") {
        let first = StarMemoMarkdownCommandBus(documentID: UUID())
        let second = StarMemoMarkdownCommandBus(documentID: UUID())
        try expect(first.engineBus.applyBoldRequest != second.engineBus.applyBoldRequest)
        try expect(first.engineBus.applyItalicRequest != second.engineBus.applyItalicRequest)
        try expect(first.engineBus.applyLinkRequest != second.engineBus.applyLinkRequest)
    },
    Check("markdown theme uses token hiding and StarMemo spacing") {
        let bus = StarMemoMarkdownCommandBus(documentID: UUID())
        let config = StarMemoMarkdownThemeFactory.make(
            appearance: .mistBlue,
            fontSize: 16,
            bus: bus.engineBus
        )
        try expect(config.markers.hiddenMarkerFontSize == 0.1)
        try expect(config.scrollers.hasVerticalScroller)
        try expect(config.textInsets.horizontal == 18)
        try expect(config.textInsets.vertical == 18)
        try expect(config.lists.indentPerLevel == 18)
    },
    Check("markdown engine keeps historical unchecked checkbox defaults") {
        let config = MarkdownEditorConfiguration.default
        try expect(abs(config.theme.taskCheckboxUncheckedFill.alphaComponent - 0.035) < 0.001)
        try expect(abs(config.theme.taskCheckboxUncheckedStroke.alphaComponent - 0.30) < 0.001)
        try expect(config.checkbox.uncheckedStrokeWidth == 1)
    },
    Check("StarMemo derives unchecked checkbox ink from each note body color") {
        let light = StarMemoMarkdownThemeFactory.make(
            appearance: .mistBlue,
            fontSize: 16,
            bus: StarMemoMarkdownCommandBus(documentID: UUID()).engineBus
        )
        let graphite = StarMemoMarkdownThemeFactory.make(
            appearance: .graphite,
            fontSize: 16,
            bus: StarMemoMarkdownCommandBus(documentID: UUID()).engineBus
        )

        try expect(
            light.theme.taskCheckboxUncheckedFill.isEqual(
                light.theme.bodyText.withAlphaComponent(0.08)
            )
        )
        try expect(
            light.theme.taskCheckboxUncheckedStroke.isEqual(
                light.theme.bodyText.withAlphaComponent(0.62)
            )
        )
        try expect(
            graphite.theme.taskCheckboxUncheckedFill.isEqual(
                graphite.theme.bodyText.withAlphaComponent(0.08)
            )
        )
        try expect(
            graphite.theme.taskCheckboxUncheckedStroke.isEqual(
                graphite.theme.bodyText.withAlphaComponent(0.62)
            )
        )
        try expect(light.checkbox.uncheckedStrokeWidth == 1.5)
        try expect(graphite.checkbox.uncheckedStrokeWidth == 1.5)
    },
]
