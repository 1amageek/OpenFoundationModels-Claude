// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenFoundationModels-Claude",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "OpenFoundationModelsClaude",
            targets: ["OpenFoundationModelsClaude"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/1amageek/OpenFoundationModels.git", from: "1.1.1"),
        .package(url: "https://github.com/apple/swift-configuration.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "OpenFoundationModelsClaude",
            dependencies: [
                .product(name: "OpenFoundationModels", package: "OpenFoundationModels"),
                .product(name: "OpenFoundationModelsExtra", package: "OpenFoundationModels"),
                .product(name: "Configuration", package: "swift-configuration")
            ]
        ),
        .testTarget(
            name: "OpenFoundationModelsClaudeTests",
            dependencies: ["OpenFoundationModelsClaude"]
        ),
    ]
)
