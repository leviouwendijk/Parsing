// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Parsing",
    // platforms: [
    //     .macOS(.v13)
    // ],
    products: [
        .library(
            name: "Parsing",
            targets: ["Parsing"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Position.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "Parsing",
            dependencies: [
                .product(name: "Position", package: "Position"),
            ],
        ),
    ]
)
