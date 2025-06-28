// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "WhisperFramework",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "WhisperFramework", targets: ["WhisperFramework"])
    ],
    targets: [
        .binaryTarget(
            name: "WhisperFramework",
            url: "https://github.com/ggml-org/whisper.cpp/releases/download/v1.7.5/whisper-v1.7.5-xcframework.zip",
            checksum: "c7faeb328620d6012e130f3d705c51a6ea6c995605f2df50f6e1ad68c59c6c4a"
        )
    ]
)

