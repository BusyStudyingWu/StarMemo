import Foundation
import StarMemoTestSupport

let menuBarOnlyChecks: [Check] = [
    Check("menu bar only bundle opts out of Dock at launch") {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Sources/StarMemoUI/Resources/Info.plist"))
        let plist = try require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        try expect(plist["LSUIElement"] as? Bool == true, "LSUIElement must prevent a Dock icon at launch")
    },
    Check("menu bar only startup does not restore regular activation") {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Sources/StarMemoApp/StarMemoApp.swift"), encoding: .utf8)
        try expect(source.contains("setActivationPolicy(.accessory)"), "Runtime policy must remain accessory")
        try expect(!source.contains("setActivationPolicy(.regular)"))
    },
]
