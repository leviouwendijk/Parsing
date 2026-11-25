// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ParsingTests",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "t_parsing", targets: ["ParsingTests"]),
        .executable(name: "t_grammar_parsing", targets: ["GrammarParsingTests"]),
        .executable(
            name: "parsingtest",
            targets: ["ParsingTests"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Primitives.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Position.git", branch: "master"),
        .package(url: "https://github.com/swift-langs/Grammar.git", branch: "master"),
        .package(url: "https://github.com/swift-langs/Syntax.git", branch: "master"),
        .package(url: "https://github.com/swift-tooling/Testing.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Errors.git", branch: "master"),
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "GrammarParsingTests",
            dependencies: [
                .product(name: "GrammarParsing", package: "Parsing"),
                .product(name: "Errors", package: "Errors"),
                .product(name: "GrammarSyntax", package: "Parsing"),
                .product(name: "Grammar", package: "Grammar"),
                .product(name: "GrammarTreeSitter", package: "Grammar"),
                .product(name: "Syntax", package: "Syntax"),
                .product(name: "SyntaxLSP", package: "Syntax"),
                .product(name: "Position", package: "Position"),
                .product(name: "Testing", package: "Testing")
            ]
        ),
        .executableTarget(
            name: "ParsingTests",
            dependencies: [
                .product(name: "Parsing", package: "Parsing"),
                .product(name: "Testing", package: "Testing"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Position", package: "Position"),
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
