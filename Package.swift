// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Parsing",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "GrammarParsing", targets: ["GrammarParsing"]),
        .library(name: "GrammarSyntax", targets: ["GrammarSyntax"]),
        .library(
            name: "Parsing",
            targets: ["Parsing"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Primitives.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Position.git", branch: "master"),
        .package(url: "https://github.com/swift-langs/Lexing.git", branch: "master"),
        .package(url: "https://github.com/swift-langs/Grammar.git", branch: "master"),
        .package(url: "https://github.com/swift-langs/Syntax.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Errors.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "Parsing",
            dependencies: [
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Position", package: "Position"),
                .product(name: "Lexing", package: "Lexing"),
                .product(name: "Errors", package: "Errors"),
            ]
        ),
        .target(
            name: "GrammarParsing",
            dependencies: [
                "Parsing",
                .product(name: "Errors", package: "Errors"),
                .product(name: "Grammar", package: "Grammar"),
                .product(name: "Lexing", package: "Lexing"),
                .product(name: "Position", package: "Position")
            ]
        ),
        .target(
            name: "GrammarSyntax",
            dependencies: [
                "GrammarParsing",
                .product(name: "Grammar", package: "Grammar"),
                .product(name: "Lexing", package: "Lexing"),
                .product(name: "Syntax", package: "Syntax")
            ]
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
