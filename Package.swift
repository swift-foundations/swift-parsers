// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "swift-parsers",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "Parsers",
            targets: ["Parsers"]
        ),
        .library(
            name: "Parsers Test Support",
            targets: ["Parsers Test Support"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-ascii-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-parser-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-parser-machine-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-format-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-time-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-source-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-async.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-clocks.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Parsers",
            dependencies: [
                .product(name: "ASCII Primitives", package: "swift-ascii-primitives"),
                .product(name: "Parser Primitives", package: "swift-parser-primitives"),
                .product(name: "Parser Machine Primitives", package: "swift-parser-machine-primitives"),
                .product(name: "Format Primitives", package: "swift-format-primitives"),
                .product(name: "Time Primitives", package: "swift-time-primitives"),
                .product(name: "Source Primitives", package: "swift-source-primitives"),
                .product(name: "Async", package: "swift-async"),
                .product(name: "Clocks", package: "swift-clocks"),
            ]
        ),
        .target(
            name: "Parsers Test Support",
            dependencies: [
                "Parsers",
            ],
            path: "Tests/Support"
        ),

        // MARK: - Tests

        .testTarget(
            name: "Parsers Tests",
            dependencies: ["Parsers Test Support"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
