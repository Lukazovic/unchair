// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "UnchairCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "UnchairCore", targets: ["UnchairCore"]),
    ],
    targets: [
        .target(name: "UnchairCore"),
        .testTarget(name: "UnchairCoreTests", dependencies: ["UnchairCore"]),
    ]
)
