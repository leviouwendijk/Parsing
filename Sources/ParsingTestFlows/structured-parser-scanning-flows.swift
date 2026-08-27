import Parsing
import TestFlows

extension ParsingFlowSuite {
    static var structuredParserScanningFlow: TestFlow {
        TestFlow(
            "structured-parser-scanning",
            tags: ["structured", "scan", "cardinality", "unicode"]
        ) {
            Step("until captures bounded content without consuming its terminator") {
                let specification = StructuredParser.Specification.sequence(
                    [
                        .literal("/*"),
                        .capture(
                            name: "body",
                            specification: .until(
                                .literal("*/")
                            )
                        ),
                        .literal("*/"),
                    ]
                )
                let compiled = try specification.compile()
                let match = try Expect.notNil(
                    compiled.match("/*alpha 👨‍👩‍👧‍👦*/"),
                    "bounded until match"
                )
                let capture = try Expect.notNil(
                    match.captures.first,
                    "bounded body capture"
                )

                try Expect.equal(
                    match.range.start.offset,
                    0,
                    "bounded match start"
                )
                try Expect.equal(
                    match.range.end.offset,
                    11,
                    "bounded match Character-offset end"
                )
                try Expect.equal(
                    capture.value,
                    "alpha 👨‍👩‍👧‍👦",
                    "bounded body value"
                )
                try Expect.equal(
                    capture.range.start.offset,
                    2,
                    "bounded capture start"
                )
                try Expect.equal(
                    capture.range.end.offset,
                    9,
                    "bounded capture Character-offset end"
                )
            }

            Step("document scanning returns absolute non-overlapping ranges") {
                let compiled = try scanningSpecification().compile()
                let source = "before user=Levi after 👨‍👩‍👧‍👦 user=Nova end"
                let matches = compiled.matches(
                    in: source
                )

                try Expect.equal(
                    matches.count,
                    2,
                    "document match count"
                )
                try Expect.equal(
                    matches[0].range.start.offset,
                    7,
                    "first absolute match start"
                )
                try Expect.equal(
                    matches[0].range.end.offset,
                    16,
                    "first absolute match end"
                )
                try Expect.equal(
                    matches[1].range.start.offset,
                    25,
                    "second absolute match start after grapheme cluster"
                )
                try Expect.equal(
                    matches[1].range.end.offset,
                    34,
                    "second absolute match end after grapheme cluster"
                )
                try Expect.equal(
                    matches[1].captures.first?.range.start.offset,
                    30,
                    "second capture absolute start"
                )
                try Expect.equal(
                    matches[1].captures.first?.value,
                    "Nova",
                    "second capture value"
                )

                let first = try Expect.notNil(
                    compiled.firstMatch(
                        in: source
                    ),
                    "first structural document match"
                )

                try Expect.equal(
                    first,
                    matches[0],
                    "firstMatch agrees with all-match scan"
                )
            }

            Step("scanning advances to the end of each successful match") {
                let compiled = try StructuredParser.Specification
                    .literal("aa")
                    .compile()
                let matches = compiled.matches(
                    in: "aaaa"
                )

                try Expect.equal(
                    matches.count,
                    2,
                    "non-overlapping match count"
                )
                try Expect.equal(
                    matches[0].range.start.offset,
                    0,
                    "first non-overlapping start"
                )
                try Expect.equal(
                    matches[0].range.end.offset,
                    2,
                    "first non-overlapping end"
                )
                try Expect.equal(
                    matches[1].range.start.offset,
                    2,
                    "second non-overlapping start"
                )
                try Expect.equal(
                    matches[1].range.end.offset,
                    4,
                    "second non-overlapping end"
                )
            }

            Step("cardinality proves match counts independently from scan selection") {
                let compiled = try scanningSpecification().compile()
                let source = "user=Levi and user=Nova"

                let exactlyTwo = try compiled.matches(
                    in: source,
                    requiring: .exactly(2)
                )

                try Expect.equal(
                    exactlyTwo.count,
                    2,
                    "exact cardinality accepted"
                )

                try StructuredParser.Cardinality.atLeast(2).validate(
                    exactlyTwo.count
                )
                try StructuredParser.Cardinality.atMost(2).validate(
                    exactlyTwo.count
                )

                var rejected = false

                do {
                    _ = try compiled.matches(
                        in: source,
                        requiring: .exactlyOne
                    )
                } catch let error as StructuredParser.CardinalityError {
                    rejected = error == .unsatisfied(
                        expected: .exactly(1),
                        actual: 2
                    )
                }

                try Expect.equal(
                    rejected,
                    true,
                    "cardinality mismatch rejected"
                )
            }

            Step("nullable until terminators are rejected before execution") {
                let invalid = StructuredParser.Specification.until(
                    .optional(
                        .literal("end")
                    )
                )
                var rejected = false

                do {
                    _ = try invalid.compile()
                } catch let error as StructuredParser.ValidationError {
                    rejected = error == .nullableUntilTerminator
                }

                try Expect.equal(
                    rejected,
                    true,
                    "nullable until terminator rejected"
                )
            }
        }
    }

    private static func scanningSpecification() -> StructuredParser.Specification {
        .sequence(
            [
                .literal("user="),
                .capture(
                    name: "name",
                    specification: .identifier
                ),
            ]
        )
    }
}
