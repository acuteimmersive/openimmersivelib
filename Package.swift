// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenImmersive",
    platforms: [
        .iOS(.v17), // Ensure it's set to 16.0 or newer
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "OpenImmersiveLib",
            targets: ["OpenImmersive"]
        ),
    ],
    targets: [
        .target(
            name: "OpenImmersive"
        ),
    ]
)
