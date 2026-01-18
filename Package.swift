// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-parsing",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "Parsing",
            targets: ["Parsing"]
        ),
        .library(
            name: "Parsing Test Support",
            targets: ["Parsing Test Support"]
        )
    ],
    dependencies: [
        .package(path: "../swift-primitives/swift-parsing-primitives"),
        .package(path: "../swift-primitives/swift-formatting-primitives"),
        .package(path: "../swift-primitives/swift-time-primitives"),
        .package(path: "../swift-primitives/swift-container-primitives"),
        .package(path: "../swift-foundations/swift-async")
    ],
    targets: [
        .target(
            name: "Parsing",
            dependencies: [
                .product(name: "Parsing Primitives", package: "swift-parsing-primitives"),
                .product(name: "Parsing Machine", package: "swift-parsing-primitives"),
                .product(name: "Formatting Primitives", package: "swift-formatting-primitives"),
                .product(name: "Time Primitives", package: "swift-time-primitives"),
                .product(name: "Container Primitives", package: "swift-container-primitives"),
                .product(name: "Async", package: "swift-async")
            ]
        ),
        .target(
            name: "Parsing Test Support",
            dependencies: [
                "Parsing",
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
