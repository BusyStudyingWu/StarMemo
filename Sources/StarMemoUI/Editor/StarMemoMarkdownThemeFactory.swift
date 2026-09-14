import AppKit
import MarkdownEngine
import StarMemoCore

public enum StarMemoMarkdownThemeFactory {
    public static func make(
        appearance: NoteAppearance,
        fontSize: CGFloat,
        bus: MarkdownEditorBus
    ) -> MarkdownEditorConfiguration {
        let palette = NoteColorPalette(appearance: appearance)
        let body = palette.ink
        let theme = MarkdownEditorTheme(
            bodyText: body,
            mutedText: body.withAlphaComponent(0.48),
            disabledText: body.withAlphaComponent(0.30),
            headingMarker: body.withAlphaComponent(0.45),
            link: .linkColor,
            incompleteLink: .systemBlue.withAlphaComponent(0.72),
            strikethroughColor: body.withAlphaComponent(0.62),
            taskCheckboxUncheckedFill: .clear,
            taskCheckboxUncheckedStroke: body.withAlphaComponent(0.62),
            taskCheckboxCheckedFill: palette.checkedTaskFill,
            taskCheckboxCheckmark: palette.taskCheckmark
        )
        return MarkdownEditorConfiguration(
            theme: theme,
            services: MarkdownEditorServices(bus: bus),
            markers: MarkerStyle(hiddenMarkerFontSize: 0.1),
            lists: ListStyle(indentPerLevel: 18, extraLineHeight: 1),
            checkbox: CheckboxStyle(uncheckedStrokeWidth: 1.5),
            overscroll: OverscrollPolicy(percent: 0, maxPoints: 0, minPoints: 0),
            scrollers: .vertical,
            textInsets: TextInsets(horizontal: 18, vertical: 18)
        )
    }

}
