import Lexing
import Parsing
import Testing

private struct IdentifierValue: SyntaxParsable {
    let value: String

    static var syntax: AnyTokenParser<Self> {
        AnyTokenParser(PIdent()).map { IdentifierValue(value: $0) }
    }
}

extension ParsingTestSuite {
    static var publicAPISuite: TestSuite {
        TestSuite("parsing-api") {
            Test("canonical grammar types preserve legacy names") {
                let _: Grammar.Node = GrammarNode(name: "root", fields: [])
                let _: Grammar.Field = GrammarField("value", .val("string"))
                let _: Grammar.Value = GrammarValue.val("string")
                let _: Grammar.Order = GrammarOrder.ordered
                let _: Grammar.Separator = GrammarSeparator.comma
                let _: Grammar.Multiplicity = GMultiplicity.one
                let _: Grammar.Result = GrammarResult.list([])
                let _: Grammar.Compiler.Type = GrammarCompiler.self
                try Expect.equal(
                    String(reflecting: Grammar.Node.self).contains("Grammar.Node"),
                    true,
                    "canonical node identity"
                )
            }

            Test("delimiter composes arbitrary character-level syntax") {
                let delimiters = Delimiter(start: "<<", end: ">>")
                switch delimiters.parser().parse(Cursor("<<value>>")) {
                case .success(let body, let next):
                    try Expect.equal(body, "value", "arbitrary delimiters")
                    try Expect.equal(next.isEOF, true, "complete consumption")
                case .failure:
                    try Expect.equal(true, false, "expected successful parser")
                }
            }

            Test("nested delimiter syntax preserves interior") {
                switch Delimiter.braces.parser().parse(Cursor("{a{b}c}")) {
                case .success(let body, _):
                    try Expect.equal(body, "a{b}c", "nested delimiters")
                case .failure:
                    try Expect.equal(true, false, "expected balanced block")
                }
            }

            Test("domain value provides its parser") {
                var lexer = Lexer(source: "alpha", sets: .init(keywords: []))
                let cursor = TokenCursor(lexedTokens: lexer.lexedTokens(), source: "alpha")
                switch try IdentifierValue.parse(cursor) {
                case .success(let result, _):
                    try Expect.equal(result.value, "alpha", "typed domain result")
                case .failure:
                    try Expect.equal(true, false, "typed parser failed")
                }
            }
        }
    }
}
