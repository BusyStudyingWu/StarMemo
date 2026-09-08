// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StarMemo",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "StarMemo", targets: ["StarMemoApp"]),
    ],
    dependencies: [
        .package(path: "Vendor/swift-markdown-engine"),
    ],
    targets: [
        .target(
            name: "StarMemoCore"
        ),
        .target(
            name: "StarMemoUI",
            dependencies: [
                "StarMemoCore",
                .product(name: "MarkdownEngine", package: "swift-markdown-engine"),
            ],
            exclude: ["Resources"]
        ),
        .executableTarget(
            name: "StarMemoApp",
            dependencies: ["StarMemoCore", "StarMemoUI"]
        ),
        .target(
            name: "StarMemoTestSupport",
            path: "Tests/Support"
        ),
        .executableTarget(
            name: "StarMemoCoreChecks",
            dependencies: ["StarMemoCore", "StarMemoTestSupport"],
            path: "Tests/StarMemoCoreChecks"
        ),
        .executableTarget(
            name: "StarMemoUIChecks",
            dependencies: [
                "StarMemoUI", "StarMemoCore", "StarMemoTestSupport",
                .product(name: "MarkdownEngine", package: "swift-markdown-engine"),
            ],
            path: "Tests/StarMemoUIChecks"
        ),
    ],
    swiftLanguageModes: [.v6]
)
