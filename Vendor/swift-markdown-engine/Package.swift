// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MarkdownEngine",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MarkdownEngine", targets: ["MarkdownEngine"]),
    ],
    targets: [
        .target(name: "MarkdownEngine"),
    ]
)
