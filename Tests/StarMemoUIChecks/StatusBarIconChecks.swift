import StarMemoTestSupport
import StarMemoUI

let statusBarIconChecks: [Check] = [
    Check("status bar uses one note and star icon without a visible title") {
        try expect(StatusBarPresentation.noteSymbolName == "note")
        try expect(StatusBarPresentation.starSymbolName == "star.fill")
        try expect(StatusBarPresentation.visibleTitle == nil)
        try expect(StatusBarPresentation.accessibilityLabel == "StarMemo")
    },
]
