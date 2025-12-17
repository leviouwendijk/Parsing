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
    targets: [
        .target(
            name: "Parsing"
        ),
        .testTarget(
            name: "ParsingTests",
            dependencies: ["Parsing"]
        ),
    ]
)
