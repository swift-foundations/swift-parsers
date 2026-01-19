// swift-tools-version: 6.2

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
        .package(path: "../swift-primitives/swift-parser-primitives"),
        .package(path: "../swift-primitives/swift-formatting-primitives"),
        .package(path: "../swift-primitives/swift-time-primitives"),
        .package(path: "../swift-foundations/swift-async")
    ],
    targets: [
        .target(
            name: "Parsers",
            dependencies: [
                .product(name: "Parser Primitives", package: "swift-parser-primitives"),
                .product(name: "Parser Machine", package: "swift-parser-primitives"),
                .product(name: "Formatting Primitives", package: "swift-formatting-primitives"),
                .product(name: "Time Primitives", package: "swift-time-primitives"),
                .product(name: "Async", package: "swift-async")
            ]
        ),
        .target(
            name: "Parsers Test Support",
            dependencies: [
                "Parsers",
                .product(name: "Test Primitives", package: "swift-test-primitives")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility")
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
