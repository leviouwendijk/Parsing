import Parsing
import Testing

extension ParsingTestSuite {
    static var tokenCompatibilitySuite: TestSuite {
        TestSuite(
            "token-compatibility",
            tags: ["lexer", "cursor", "compatibility"]
        ) {
            Test("nextToken remains the token projection of positioned lexing") {
                let source = "alpha beta"

                var tokenLexer = Lexer(
                    source: source,
                    sets: Lexer.Vocabulary(keywords: [])
                )
                var positionedLexer = Lexer(
                    source: source,
                    sets: Lexer.Vocabulary(keywords: [])
                )

                let tokens = tokenLexer.collectAllTokens()
                let positioned = positionedLexer.lexedTokens()

                try Expect.equal(
                    tokens,
                    positioned.map(\.token),
                    "classic and positioned token sequences"
                )
            }
        }
    }
}
