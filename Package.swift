// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Parsing",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "t_parsing", targets: ["ParsingTests"]),
        .library(
            name: "Parsing",
            targets: ["Parsing"]
        ),
        .executable(
            name: "parsingtest",
            targets: ["ParsingTests"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Primitives.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Position.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Testing.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "Parsing",
            dependencies: [
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Position", package: "Position"),
            ]
        ),
        .executableTarget(
            name: "ParsingTests",
            dependencies: [
                "Parsing",
                .product(name: "Testing", package: "Testing"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Position", package: "Position"),
            ],
            path: "Testing/ParsingTests"
        ),
    ]
)

for target in package.targets {
    switch target.type {
    case .regular, .executable, .test, .macro:
        var settings = target.swiftSettings ?? []

        settings.append(
            .treatAllWarnings(as: .error)
        )

        settings.append(
            .unsafeFlags(
                [
                    "-continue-building-after-errors"
                ]
            )
        )

        target.swiftSettings = settings

    case .plugin, .system, .binary:
        break

    @unknown default:
        break
    }
}
