// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SimpodHelper",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.1"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.25.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-websocket.git", from: "2.7.0"),
    ],
    targets: [
        .executableTarget(
            name: "simpod-helper-bin",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdWebSocket", package: "hummingbird-websocket"),
            ],
            path: "Sources/SimpodHelper",
            linkerSettings: [
                .linkedFramework("IOSurface"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("ImageIO"),
                .linkedFramework("VideoToolbox"),
            ]
        ),
        .testTarget(
            name: "SimpodHelperTests",
            dependencies: ["simpod-helper-bin"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
