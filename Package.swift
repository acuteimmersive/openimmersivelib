// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenImmersive",
    platforms: [.visionOS(.v2)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "OpenImmersiveLib",
            targets: ["OpenImmersive"]),
    ],
    dependencies: [
        .package(url: "https://github.com/dagronf/SwiftSubtitles", from: "2.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "OpenImmersive",
            dependencies: [
                .product(name: "SwiftSubtitles", package: "SwiftSubtitles")
            ]
        ),
        .testTarget(
            name: "OpenImmersiveTests",
            dependencies: ["OpenImmersive"],
            resources: [.process("TestAssets")]
        ),

    ]
)
