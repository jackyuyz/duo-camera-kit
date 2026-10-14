// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Library",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "Library", targets: ["Library"])
    ],
    dependencies: [
        .package(name: "LinkKit", path: "../LinkKit")
    ],
    targets: [
        .target(
            name: "Library",
            dependencies: ["LinkKit"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "LibraryTests",
            dependencies: ["Library"]
        )
    ]
)
