// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YabaiBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "YabaiBar",
            path: "Sources/YabaiBar",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
