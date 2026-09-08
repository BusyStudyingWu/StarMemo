import StarMemoCore
import StarMemoTestSupport

@main
struct CoreChecks {
    @MainActor
    static func main() async {
        await TestHarness.run([
            Check("core module loads") {
                try expect(StarMemoCore.moduleName == "StarMemoCore")
            },
        ] + markdownDocumentChecks
            + documentStoreChecks
            + persistenceStoreChecks
            + markdownParserChecks
            + markdownPreviewChecks
            + markdownEditingChecks)
    }
}
