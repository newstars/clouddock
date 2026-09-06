// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "CloudDock",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CloudDock", targets: ["CloudDock"])
    ],
    targets: [
        .executableTarget(
            name: "CloudDock",
            path: "Sources/CloudDock"
        )
    ]
)
