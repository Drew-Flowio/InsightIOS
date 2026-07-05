// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "InsightLlama",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "InsightLlama", targets: ["InsightLlama"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mattt/llama.swift", .upToNextMajor(from: "2.9878.0")),
        .package(path: "../InsightCore"),
        .package(path: "../InsightRuntime"),
    ],
    targets: [
        .target(
            name: "InsightLlama",
            dependencies: [
                .product(name: "LlamaSwift", package: "llama.swift"),
                "InsightCore",
                "InsightRuntime",
            ]
        ),
        .testTarget(
            name: "InsightLlamaTests",
            dependencies: ["InsightLlama"]
        ),
    ]
)
