// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Parsing",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Parsing",
            targets: ["Parsing"]
        ),
        .executable(
            name: "parsingtest",
            targets: ["ParsingTestFlows"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Position.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/TestFlows.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "Parsing",
            dependencies: [
                .product(name: "Position", package: "Position"),
            ]
        ),
        .executableTarget(
            name: "ParsingTestFlows",
            dependencies: [
                "Parsing",
                .product(name: "Position", package: "Position"),
                .product(name: "TestFlows", package: "TestFlows"),
            ]
        ),
    ]
)
