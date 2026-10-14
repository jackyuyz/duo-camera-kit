// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LinkKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "LinkKit", targets: ["LinkKit"])
    ],
    dependencies: [
        .package(name: "CameraKit", path: "../CameraKit")
    ],
    targets: [
        .target(
            name: "LinkKit",
            dependencies: ["CameraKit"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "LinkKitTests",
            dependencies: ["LinkKit"]
        )
    ]
)
