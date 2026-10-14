// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StreamKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "StreamKit", targets: ["StreamKit"])
    ],
    targets: [
        .target(
            name: "StreamKit",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "StreamKitTests",
            dependencies: ["StreamKit"]
        )
    ]
)
