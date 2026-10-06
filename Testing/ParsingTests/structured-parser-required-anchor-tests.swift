import Parsing
import Testing

extension ParsingTestSuite {
    static var structuredParserRequiredAnchorSuite: TestSuite {
        TestSuite(
            "structured-parser-required-anchors",
            tags: [
                "structured",
                "anchor",
                "search",
                "grammar",
            ]
        ) {
            Test("sequence unions literal anchors and capture delegates to its child") {
                let specification = StructuredParser.Specification.sequence(
                    [
                        .literal("user"),
                        .capture(
                            name: "assignment",
                            specification: .sequence(
                                [
                                    .literal("="),
                                    .identifier,
                                ]
                            )
                        ),
                        .literal(";"),
                    ]
                )

                try Expect.equal(
                    try specification.requiredAnchors(),
                    [
                        .literal("user"),
                        .literal("="),
                        .literal(";"),
                    ],
                    "sequence requires every child anchor while identifier contributes no literal anchor"
                )
            }

            Test("choice keeps only anchors required by every alternative") {
                let specification = StructuredParser.Specification.choice(
                    [
                        .sequence(
                            [
                                .literal("case"),
                                .literal("alpha"),
                            ]
                        ),
                        .sequence(
                            [
                                .literal("case"),
                                .literal("beta"),
                            ]
                        ),
                    ]
                )

                try Expect.equal(
                    try specification.requiredAnchors(),
                    [
                        .literal("case"),
                    ],
                    "choice intersection cannot require branch-specific literals"
                )

                try Expect.equal(
                    try StructuredParser.Specification.choice(
                        [
                            .literal("alpha"),
                            .literal("beta"),
                        ]
                    ).requiredAnchors(),
                    [],
                    "disjoint alternatives have no safe required anchor"
                )
            }

            Test("optional and zero-minimum repetition contribute no required anchors") {
                let specification = StructuredParser.Specification.sequence(
                    [
                        .literal("root"),
                        .optional(
                            .literal("optional")
                        ),
                        .repetition(
                            specification: .literal("zero"),
                            minimum: 0,
                            maximum: 3
                        ),
                    ]
                )

                try Expect.equal(
                    try specification.requiredAnchors(),
                    [
                        .literal("root"),
                    ],
                    "nullable branches cannot become required search evidence"
                )
            }

            Test("positive repetition, until, and balanced expose guaranteed literals") {
                let specification = StructuredParser.Specification.sequence(
                    [
                        .repetition(
                            specification: .literal("item"),
                            minimum: 1,
                            maximum: 3
                        ),
                        .until(
                            .literal("end")
                        ),
                        .balanced(
                            opening: "{",
                            closing: "}"
                        ),
                    ]
                )

                let anchors = try specification.requiredAnchors()

                try Expect.equal(
                    anchors,
                    [
                        .literal("item"),
                        .literal("end"),
                        .literal("{"),
                        .literal("}"),
                    ],
                    "positive repetition, until terminator, and balanced delimiters are necessary evidence"
                )

                let compiled = try specification.compile()

                try Expect.equal(
                    compiled.requiredAnchors,
                    anchors,
                    "compiled parser exposes the same conservative anchor facts without revalidation"
                )
            }

            Test("grammar resolves references before anchor analysis") {
                let grammar = StructuredParser.Grammar(
                    root: .sequence(
                        [
                            .literal("let "),
                            .reference("assignment"),
                        ]
                    ),
                    definitions: [
                        .init(
                            name: "assignment",
                            specification: .sequence(
                                [
                                    .literal("="),
                                    .identifier,
                                ]
                            )
                        ),
                    ]
                )

                try Expect.equal(
                    try grammar.requiredAnchors(),
                    [
                        .literal("let "),
                        .literal("="),
                    ],
                    "grammar-owned reference semantics remain resolved before search facts are derived"
                )
            }

            Test("duplicate required literals collapse to stable necessary evidence") {
                let specification = StructuredParser.Specification.sequence(
                    [
                        .literal("foo"),
                        .literal("foo"),
                        .capture(
                            name: "again",
                            specification: .literal("foo")
                        ),
                    ]
                )

                try Expect.equal(
                    try specification.requiredAnchors(),
                    [
                        .literal("foo"),
                    ],
                    "anchor analysis expresses necessary presence rather than multiplicity proof"
                )
            }
        }
    }
}
