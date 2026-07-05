// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "InsightRuntime",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "InsightRuntime", targets: ["InsightRuntime"]),
    ],
    dependencies: [
        .package(path: "../InsightCore"),
    ],
    targets: [
        .target(
            name: "InsightRuntime",
            dependencies: ["InsightCore"]
        ),
        .testTarget(
            name: "InsightRuntimeTests",
            dependencies: ["InsightRuntime"]
        ),
    ]
)
