// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "InsightCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "InsightCore", targets: ["InsightCore"]),
    ],
    dependencies: [
        .package(path: "../InsightStorage"),
    ],
    targets: [
        .target(
            name: "InsightCore",
            dependencies: ["InsightStorage"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "InsightCoreTests",
            dependencies: ["InsightCore"]
        ),
    ]
)
