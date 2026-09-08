import Foundation
import StarMemoCore
import StarMemoTestSupport

let markdownDocumentChecks: [Check] = [
    Check("storage status distinguishes recovery protection from a saved file") {
        let document = MarkdownDocument(text: "draft")
        try expect(document.storageStatusTitle == "未保存")
        document.markRecoveryProtected()
        try expect(document.storageStatusTitle == "未保存")
        try expect(document.storageStatusDetail.contains("恢复副本") && document.storageStatusDetail.contains("尚未"))
        document.text = "changed"
        try expect(document.draftProtection == .pending)
        document.markRecoveryFailed("disk full")
        try expect(document.storageStatusDetail.contains("disk full"))
        document.markSaved(to: URL(fileURLWithPath: "/tmp/status.md"), modificationDate: nil)
        try expect(document.storageStatusTitle == "已保存")
        document.text = "new edit"
        try expect(document.storageStatusTitle == "已修改")
    },
    Check("new document starts clean") {
        let document = MarkdownDocument()
        try expect(!document.isDirty, "A new empty document should be clean")
        try expect(document.displayTitle == "未命名便笺")
    },
    Check("editing and discard track dirty state") {
        let document = MarkdownDocument(text: "hello", savedText: "hello")
        document.text = "changed"
        try expect(document.isDirty)
        document.discardChanges()
        try expect(document.text == "hello")
        try expect(!document.isDirty)
    },
    Check("mark saved records snapshot URL and date") {
        let date = Date(timeIntervalSince1970: 1_234)
        let url = URL(fileURLWithPath: "/tmp/旅行计划.md")
        let document = MarkdownDocument(text: "body")
        document.markSaved(to: url, modificationDate: date)
        try expect(!document.isDirty)
        try expect(document.fileURL == url)
        try expect(document.lastKnownModificationDate == date)
        try expect(document.displayTitle == "旅行计划")
    },
    Check("suggested title is used before first save") {
        let document = MarkdownDocument(suggestedTitle: "灵感")
        try expect(document.displayTitle == "灵感")
    },
]
