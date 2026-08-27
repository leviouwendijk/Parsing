import Foundation
import Parsing
import TestFlows

extension ParsingFlowSuite {
    static var structuredParserGrammarFlow: TestFlow {
        TestFlow(
            "structured-parser-grammar",
            tags: ["structured", "grammar", "balanced", "reference", "unicode"]
        ) {
            Step("grammar round-trips and resolves reusable named references") {
                let grammar = referenceGrammar()
                let encoded = try JSONEncoder().encode(grammar)
                let decoded = try JSONDecoder().decode(
                    StructuredParser.Grammar.self,
                    from: encoded
                )

                try Expect.equal(
                    decoded,
                    grammar,
                    "structured grammar Codable round trip"
                )

                let compiled = try decoded.compile()
                let match = try Expect.notNil(
                    compiled.match("user=Levi"),
                    "resolved reference exact match"
                )
                let capture = try Expect.notNil(
                    match.captures.first,
                    "resolved reference capture"
                )

                try Expect.equal(
                    match.range.end.offset,
                    9,
                    "resolved match Character-offset end"
                )
                try Expect.equal(
                    capture.value,
                    "Levi",
                    "resolved reference capture value"
                )
                try Expect.equal(
                    capture.range.start.offset,
                    5,
                    "resolved reference capture start"
                )
                try Expect.equal(
                    capture.range.end.offset,
                    9,
                    "resolved reference capture end"
                )
            }

            Step("balanced consumes nested delimiters with Character offsets") {
                let compiled = try StructuredParser.Specification
                    .sequence(
                        [
                            .literal("payload="),
                            .capture(
                                name: "payload",
                                specification: .balanced(
                                    opening: "{",
                                    closing: "}"
                                )
                            ),
                        ]
                    )
                    .compile()
                let source = "payload={alpha{beta}👨‍👩‍👧‍👦}"
                let match = try Expect.notNil(
                    compiled.match(source),
                    "nested balanced match"
                )
                let capture = try Expect.notNil(
                    match.captures.first,
                    "balanced capture"
                )

                try Expect.equal(
                    match.range.end.offset,
                    22,
                    "balanced match Character-offset end"
                )
                try Expect.equal(
                    capture.range.start.offset,
                    8,
                    "balanced capture start"
                )
                try Expect.equal(
                    capture.range.end.offset,
                    22,
                    "balanced capture end"
                )
                try Expect.equal(
                    capture.value,
                    "{alpha{beta}👨‍👩‍👧‍👦}",
                    "balanced capture value"
                )
                try Expect.equal(
                    compiled.match("payload={alpha{beta}") == nil,
                    true,
                    "unclosed balanced structure fails"
                )
            }

            Step("grammar rejects missing and duplicate definitions") {
                var missingRejected = false

                do {
                    _ = try StructuredParser.Grammar(
                        root: .reference("missing")
                    ).compile()
                } catch let error as StructuredParser.ValidationError {
                    missingRejected = error == .undefinedReference(
                        "missing"
                    )
                }

                try Expect.equal(
                    missingRejected,
                    true,
                    "undefined reference rejected"
                )

                var duplicateRejected = false

                do {
                    _ = try StructuredParser.Grammar(
                        root: .reference("value"),
                        definitions: [
                            .init(
                                name: "value",
                                specification: .literal("a")
                            ),
                            .init(
                                name: "value",
                                specification: .literal("b")
                            ),
                        ]
                    ).compile()
                } catch let error as StructuredParser.ValidationError {
                    duplicateRejected = error == .duplicateDefinition(
                        "value"
                    )
                }

                try Expect.equal(
                    duplicateRejected,
                    true,
                    "duplicate definition rejected"
                )
            }

            Step("grammar rejects recursive reference graphs") {
                let grammar = StructuredParser.Grammar(
                    root: .reference("a"),
                    definitions: [
                        .init(
                            name: "a",
                            specification: .reference("b")
                        ),
                        .init(
                            name: "b",
                            specification: .reference("a")
                        ),
                    ]
                )
                var rejected = false

                do {
                    _ = try grammar.compile()
                } catch let error as StructuredParser.ValidationError {
                    if case .recursiveReference(let path) = error {
                        rejected = path == ["a", "b", "a"]
                    }
                }

                try Expect.equal(
                    rejected,
                    true,
                    "indirect recursive reference rejected"
                )
            }

            Step("references require grammar scope and balanced delimiters are validated") {
                var standaloneRejected = false

                do {
                    _ = try StructuredParser.Specification
                        .reference("value")
                        .compile()
                } catch let error as StructuredParser.ValidationError {
                    standaloneRejected = error == .referenceRequiresGrammar(
                        "value"
                    )
                }

                try Expect.equal(
                    standaloneRejected,
                    true,
                    "standalone reference rejected"
                )

                var balancedRejected = false

                do {
                    _ = try StructuredParser.Specification
                        .balanced(
                            opening: "{",
                            closing: "{"
                        )
                        .compile()
                } catch let error as StructuredParser.ValidationError {
                    balancedRejected = error == .invalidBalancedDelimiters(
                        opening: "{",
                        closing: "{"
                    )
                }

                try Expect.equal(
                    balancedRejected,
                    true,
                    "ambiguous balanced delimiters rejected"
                )
            }
        }
    }

    private static func referenceGrammar() -> StructuredParser.Grammar {
        StructuredParser.Grammar(
            root: .sequence(
                [
                    .literal("user="),
                    .capture(
                        name: "name",
                        specification: .reference("value")
                    ),
                ]
            ),
            definitions: [
                .init(
                    name: "value",
                    specification: .identifier
                ),
            ]
        )
    }
}
