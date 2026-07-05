// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "InsightEngine",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "InsightEngine", targets: ["InsightEngine"]),
    ],
    dependencies: [
        .package(path: "../InsightCore"),
        .package(path: "../InsightStorage"),
        .package(path: "../InsightRuntime"),
        .package(path: "../InsightLlama"),
        .package(path: "../InsightWhisper"),
        .package(path: "../InsightVoice"),
    ],
    targets: [
        .target(
            name: "InsightEngine",
            dependencies: [
                "InsightCore",
                "InsightStorage",
                "InsightRuntime",
                "InsightLlama",
                "InsightWhisper",
                "InsightVoice",
            ]
        ),
        .testTarget(
            name: "InsightEngineTests",
            dependencies: ["InsightEngine"]
        ),
    ]
)
