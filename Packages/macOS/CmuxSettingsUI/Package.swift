// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CmuxSettingsUI",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CmuxSettingsUI",
            targets: ["CmuxSettingsUI"]
        ),
    ],
    dependencies: [
        .package(path: "../CmuxSettings"),
        .package(path: "../CmuxMCPManager"),
    ],
    targets: [
        .target(
            name: "CmuxSettingsUI",
            dependencies: [
                .product(name: "CmuxSettings", package: "CmuxSettings"),
                .product(name: "CmuxMCPManager", package: "CmuxMCPManager"),
            ]
        ),
        .testTarget(
            name: "CmuxSettingsUITests",
            dependencies: ["CmuxSettingsUI"]
        ),
    ]
)
