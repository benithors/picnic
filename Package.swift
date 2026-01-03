// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Picnic",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Picnic", targets: ["ScreenshotAI"])
    ],
    targets: [
        .executableTarget(
            name: "ScreenshotAI",
            path: "Sources/ScreenshotAI",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
