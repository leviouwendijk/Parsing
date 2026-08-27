import Parsing
import TestFlows

extension ParsingFlowSuite {
    static var tokenCompatibilityFlow: TestFlow {
        TestFlow(
            "token-compatibility",
            tags: ["lexer", "cursor", "compatibility"]
        ) {
            Step("nextToken remains the token projection of positioned lexing") {
                let source = "alpha beta"

                var tokenLexer = Lexer(
                    source: source,
                    sets: LexingSets(keywords: [])
                )
                var positionedLexer = Lexer(
                    source: source,
                    sets: LexingSets(keywords: [])
                )

                let tokens = tokenLexer.collectAllTokens()
                let positioned = positionedLexer.lexedTokens()

                try Expect.equal(
                    tokens,
                    positioned.map(\.token),
                    "classic and positioned token sequences"
                )
            }

            Step("deprecated line-map cursor construction remains executable") {
                var lexer = Lexer(
                    source: "alpha beta",
                    sets: LexingSets(keywords: [])
                )

                let (tokens, lines) = lexer.collectAllTokensWithLineMap()
                var cursor = TokenCursor(
                    tokens,
                    lineMap: lines,
                    filePath: "compatibility.txt"
                )

                try Expect.equal(
                    cursor.peek(),
                    .identifier("alpha"),
                    "legacy cursor peek"
                )
                try Expect.equal(
                    cursor.lineMap,
                    lines,
                    "legacy line map projection"
                )

                let location = try Expect.notNil(
                    cursor.loc(),
                    "legacy cursor location"
                )
                try Expect.equal(
                    location.line,
                    lines[0],
                    "legacy cursor line"
                )

                cursor.advance()
                try Expect.equal(
                    cursor.peek(),
                    .identifier("beta"),
                    "legacy cursor advance"
                )
            }
        }
    }
}
