// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ThockYou",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ThockYou", targets: ["ThockYou"])
    ],
    targets: [
        .executableTarget(
            name: "ThockYou",
            path: "Sources/ThockYou"
        )
    ]
)
