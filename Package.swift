// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PostureBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PostureBar", targets: ["PostureBar"])
    ],
    targets: [
        .executableTarget(
            name: "PostureBar",
            path: "Sources/PostureBar"
        ),
        .testTarget(
            name: "PostureBarTests",
            dependencies: ["PostureBar"],
            path: "Tests/PostureBarTests"
        )
    ]
)
