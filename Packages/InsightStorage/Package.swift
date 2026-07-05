// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "InsightStorage",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "InsightStorage", targets: ["InsightStorage"]),
    ],
    targets: [
        .target(name: "InsightStorage"),
        .testTarget(
            name: "InsightStorageTests",
            dependencies: ["InsightStorage"]
        ),
    ]
)
