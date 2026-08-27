import Foundation
import Parsing
import TestFlows

extension ParsingFlowSuite {
    static var structuredParserFlow: TestFlow {
        TestFlow(
            "structured-parser",
            tags: ["structured", "codable", "position"]
        ) {
            Step("specification round-trips as a manufacturable value") {
                let specification = fixtureSpecification()
                let encoded = try JSONEncoder().encode(specification)
                let decoded = try JSONDecoder().decode(
                    StructuredParser.Specification.self,
                    from: encoded
                )

                try Expect.equal(
                    decoded,
                    specification,
                    "structured parser specification Codable round trip"
                )
            }

            Step("compiled specification returns exact match and capture ranges") {
                let compiled = try fixtureSpecification().compile()
                let match = try Expect.notNil(
                    compiled.match("user=Levi!?"),
                    "structured parser match"
                )

                try Expect.equal(
                    match.range.start.offset,
                    0,
                    "match start"
                )
                try Expect.equal(
                    match.range.end.offset,
                    11,
                    "match end"
                )
                try Expect.equal(
                    match.captures.count,
                    1,
                    "capture count"
                )

                let capture = try Expect.notNil(
                    match.captures.first,
                    "name capture"
                )

                try Expect.equal(
                    capture.name,
                    "name",
                    "capture name"
                )
                try Expect.equal(
                    capture.value,
                    "Levi",
                    "capture value"
                )
                try Expect.equal(
                    capture.range.start.offset,
                    5,
                    "capture start"
                )
                try Expect.equal(
                    capture.range.end.offset,
                    9,
                    "capture end"
                )
                try Expect.equal(
                    compiled.match("user=Levi!? trailing") == nil,
                    true,
                    "match requires full structural consumption"
                )
            }

            Step("validation rejects repetition that cannot make progress") {
                let invalid = StructuredParser.Specification.repetition(
                    specification: .optional(
                        .literal("x")
                    ),
                    minimum: 0,
                    maximum: nil
                )
                var rejected = false

                do {
                    _ = try invalid.compile()
                } catch let error as StructuredParser.ValidationError {
                    rejected = error == .nonConsumingRepetition
                }

                try Expect.equal(
                    rejected,
                    true,
                    "nullable unbounded repetition rejected"
                )
            }
        }
    }

    private static func fixtureSpecification() -> StructuredParser.Specification {
        .sequence(
            [
                .choice(
                    [
                        .literal("name"),
                        .literal("user"),
                    ]
                ),
                .literal("="),
                .capture(
                    name: "name",
                    specification: .identifier
                ),
                .optional(
                    .literal("!")
                ),
                .repetition(
                    specification: .literal("?"),
                    minimum: 0,
                    maximum: 2
                ),
            ]
        )
    }
}
