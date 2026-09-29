// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-parsers",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(
            name: "Parsers",
            targets: ["Parsers"]
        ),
        .library(
            name: "Parsers Test Support",
            targets: ["Parsers Test Support"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-atoms/swift-ascii.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-atoms/swift-parser.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-parser-machine.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-atoms/swift-formatter.git",
            branch: "main", traits: ["Number", "Time"]),
        .package(
            url: "https://github.com/swift-atoms/swift-time.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-source.git",
            branch: "main"
        ),
        .package(url: "https://github.com/swift-compositions/swift-clocks.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Parsers",
            dependencies: [
                .product(name: "ASCII", package: "swift-ascii"),
                .product(name: "Parser", package: "swift-parser"),
                .product(
                    name: "Parser Machine",
                    package: "swift-parser-machine"
                ),
                .product(name: "Formatter", package: "swift-formatter"),
                .product(name: "Time", package: "swift-time"),
                .product(name: "Source", package: "swift-source"),
                .product(name: "Clocks", package: "swift-clocks"),
            ]
        ),
        .target(
            name: "Parsers Test Support",
            dependencies: [
                "Parsers"
            ],
            path: "Tests/Support"
        ),

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
        .enableExperimentalFeature("Lifetimes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
