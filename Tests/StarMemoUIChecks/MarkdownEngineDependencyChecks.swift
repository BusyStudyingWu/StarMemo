import MarkdownEngine
import StarMemoTestSupport

let markdownEngineDependencyChecks: [Check] = [
    Check("MarkdownEngine dependency loads in the UI target") {
        let configuration = MarkdownEditorConfiguration.default
        try expect(configuration.markers.hiddenMarkerFontSize > 0)
        try expect(configuration.scrollers.hasVerticalScroller)
    },
]
