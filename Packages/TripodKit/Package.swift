// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TripodKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "TripodKit", targets: ["TripodKit"])
    ],
    dependencies: [
        .package(name: "FoldKit", path: "../FoldKit")
    ],
    targets: [
        .target(
            name: "TripodKit",
            dependencies: ["FoldKit"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "TripodKitTests",
            dependencies: ["TripodKit"]
        )
    ]
)
