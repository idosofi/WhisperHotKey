// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "WhisperFramework",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "WhisperFramework",
            targets: ["WhisperFramework"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "WhisperFramework",
            path: "./Whisper.xcframework"
        ),
    ]
)

