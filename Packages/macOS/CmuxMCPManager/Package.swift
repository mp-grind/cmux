// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CmuxMCPManager",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CmuxMCPManager",
            targets: ["CmuxMCPManager"]
        ),
    ],
    dependencies: [
        .package(path: "../../../vendor/agentdeck"),
    ],
    targets: [
        .target(
            name: "CmuxMCPManager",
            dependencies: [
                .product(name: "AgentDeckCore", package: "AgentDeck"),
            ]
        ),
        .testTarget(
            name: "CmuxMCPManagerTests",
            dependencies: ["CmuxMCPManager"]
        ),
    ]
)
