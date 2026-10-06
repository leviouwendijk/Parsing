public extension StructuredParser {
    /// A source fragment that must occur whenever a compiled structured parser
    /// succeeds. Required anchors are necessary evidence only; they are never
    /// sufficient proof of a structural match.
    enum RequiredAnchor:
        Sendable,
        Codable,
        Hashable
    {
        case literal(String)
    }
}

public extension StructuredParser.Specification {
    /// Derive conservative required anchors from a validated standalone
    /// specification.
    func requiredAnchors() throws -> [StructuredParser.RequiredAnchor] {
        try compile().requiredAnchors
    }
}

public extension StructuredParser.Grammar {
    /// Resolve grammar references first, then derive conservative required
    /// anchors from the compiled root specification.
    func requiredAnchors() throws -> [StructuredParser.RequiredAnchor] {
        try compile().requiredAnchors
    }
}

public extension StructuredParser.Compiled {
    /// Conservative source anchors guaranteed by this compiled parser.
    var requiredAnchors: [StructuredParser.RequiredAnchor] {
        StructuredParserRequiredAnchorAnalysis.requiredAnchors(
            in: specification
        )
    }
}

private enum StructuredParserRequiredAnchorAnalysis {
    typealias Anchor = StructuredParser.RequiredAnchor
    typealias Specification = StructuredParser.Specification

    static func requiredAnchors(
        in specification: Specification
    ) -> [Anchor] {
        switch specification {
        case .literal(let value):
            return [
                .literal(value),
            ]

        case .identifier:
            return []

        case .sequence(let children):
            return unique(
                children.flatMap {
                    requiredAnchors(
                        in: $0
                    )
                }
            )

        case .choice(let alternatives):
            return requiredByEveryAlternative(
                alternatives
            )

        case .optional:
            return []

        case .repetition(
            let child,
            let minimum,
            _
        ):
            guard minimum > 0 else {
                return []
            }

            return requiredAnchors(
                in: child
            )

        case .capture(
            _,
            let child
        ):
            return requiredAnchors(
                in: child
            )

        case .until(let terminator):
            return requiredAnchors(
                in: terminator
            )

        case .balanced(
            let opening,
            let closing
        ):
            return unique(
                [
                    .literal(opening),
                    .literal(closing),
                ]
            )

        case .reference:
            // Standalone references fail validation, and grammar compilation
            // resolves references before constructing Compiled. Keep this
            // fallback empty so anchor analysis can never manufacture an
            // unsafe requirement from unresolved structure.
            return []
        }
    }

    static func requiredByEveryAlternative(
        _ alternatives: [Specification]
    ) -> [Anchor] {
        guard let first = alternatives.first else {
            return []
        }

        let firstAnchors = requiredAnchors(
            in: first
        )
        var shared = Set(
            firstAnchors
        )

        for alternative in alternatives.dropFirst() {
            shared.formIntersection(
                requiredAnchors(
                    in: alternative
                )
            )
        }

        return firstAnchors.filter {
            shared.contains($0)
        }
    }

    static func unique(
        _ anchors: [Anchor]
    ) -> [Anchor] {
        var seen: Set<Anchor> = []

        return anchors.filter {
            seen.insert($0).inserted
        }
    }
}
