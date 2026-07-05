// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "InsightVoice",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "InsightVoice", targets: ["InsightVoice"]),
    ],
    dependencies: [
        .package(path: "../InsightCore"),
        .package(path: "../InsightRuntime"),
    ],
    targets: [
        .target(
            name: "InsightVoice",
            dependencies: ["InsightCore", "InsightRuntime"],
            resources: [.process("Resources")]
        ),
    ]
)
