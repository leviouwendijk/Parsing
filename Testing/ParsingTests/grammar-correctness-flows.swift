import Foundation
import Parsing
import Testing

extension ParsingTestSuite {
    static var grammarCorrectnessSuite: TestSuite {
        TestSuite("grammar-correctness", tags: ["grammar", "correctness"]) {
            Test("duplicate node declarations throw rather than trap") {
                let nodes = [
                    GrammarNode(name: "duplicate", fields: []),
                    GrammarNode(name: "duplicate", fields: [])
                ]
                do {
                    _ = try Grammar(
                        nodes: nodes,
                        values: .basic(),
                        child: { AnyTokenParser<SyntaxNode> { _ in .failure(Diagnostic("unused")) } }
                    )
                    try Expect.equal(true, false, "duplicate grammar must fail")
                } catch let error as GrammarError {
                    try Expect.equal(error, .duplicate_node("duplicate"), "typed duplicate error")
                }
            }

            Test("empty parser chains are valid identities") {
                let parser: AnyTokenParser<[String]> = chain([])
                let cursor = TokenCursor(lexedTokens: [], source: "")
                switch parser.parse(cursor) {
                case .success(let values, let next):
                    try Expect.equal(values.isEmpty, true, "empty sequence")
                    try Expect.equal(next.index, cursor.index, "no consumption")
                case .failure:
                    try Expect.equal(true, false, "empty chain should not fail")
                }
            }

            Test("empty alternatives fail with a diagnostic instead of crashing") {
                let grammar = try Grammar(
                    nodes: [GrammarNode(
                        name: "root",
                        delimiter: .none,
                        order: .ordered,
                        fields: [GrammarField("x", .oneOf([]))]
                    )],
                    values: .basic(),
                    child: { AnyTokenParser<SyntaxNode> { _ in .failure(Diagnostic("unused")) } }
                )
                var lexer = Lexer(source: "x", sets: LexingSets(keywords: ["x"]))
                let cursor = TokenCursor(lexedTokens: lexer.lexedTokens(), source: "x")
                switch GrammarCompiler.compile(grammar, node: "root").parse(cursor) {
                case .failure: break
                case .success: try Expect.equal(true, false, "empty choice must fail")
                }
            }

            Test("duplicate anonymous map keys fail without trapping") {
                let grammar = try Grammar(
                    nodes: [GrammarNode(
                        name: "pairs",
                        opener: .raw("pairs"),
                        delimiter: .braces,
                        fields: [GrammarField("kv", .map(.val("string")))]
                    )],
                    values: .basic(),
                    child: { AnyTokenParser<SyntaxNode> { _ in .failure(Diagnostic("unused")) } }
                )
                let source = #"pairs { a = "x"; a = "y" }"#
                var lexer = Lexer(source: source, sets: LexingSets(keywords: ["pairs", "kv"]))
                let cursor = TokenCursor(lexedTokens: lexer.lexedTokens(), source: source)
                switch GrammarCompiler.compile(grammar, node: "pairs").parse(cursor) {
                case .failure: break
                case .success: try Expect.equal(true, false, "duplicate map key must fail")
                }
            }
        }
    }
}
