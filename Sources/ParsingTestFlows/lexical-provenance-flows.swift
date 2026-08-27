import Foundation
import Parsing
import Position
import TestFlows

extension ParsingFlowSuite {
    static var lexicalProvenanceFlow: TestFlow {
        TestFlow(
            "lexical-provenance",
            tags: ["lexer", "position", "unicode"]
        ) {
            Step("positioned lexing uses Character offsets and excludes skipped trivia") {
                let source = "alpha 👨‍👩‍👧‍👦 beta"
                var lexer = Lexer(
                    source: source,
                    sets: LexingSets(keywords: [])
                )
                let lexed = lexer.lexedTokens()

                try Expect.equal(
                    lexed.map(\.token),
                    [.identifier("alpha"), .identifier("beta"), .eof],
                    "lexical token sequence"
                )
                try Expect.equal(
                    lexed.map { $0.range.start.offset },
                    [0, 8, 12],
                    "lexical Character start offsets"
                )
                try Expect.equal(
                    lexed.map { $0.range.end.offset },
                    [5, 12, 12],
                    "lexical Character end offsets"
                )
            }
        }
    }

    static var tokenCursorProvenanceFlow: TestFlow {
        TestFlow(
            "token-cursor-provenance",
            tags: ["cursor", "position", "range"]
        ) {
            Step("cursor preserves token ergonomics while deriving exact source ranges") {
                let source = "alpha beta"
                var lexer = Lexer(
                    source: source,
                    sets: LexingSets(keywords: [])
                )
                let lexed = lexer.lexedTokens()
                var cursor = TokenCursor(
                    lexedTokens: lexed,
                    source: source,
                    filePath: "fixture.txt"
                )
                let start = cursor.mark()

                try Expect.equal(
                    cursor.peek(),
                    .identifier("alpha"),
                    "peek still returns Token"
                )

                cursor.advance()
                cursor.advance()

                let range = try Expect.notNil(
                    cursor.sourceRange(from: start),
                    "cursor source range"
                )
                try Expect.equal(range.start.offset, 0, "cursor range start")
                try Expect.equal(range.end.offset, 10, "cursor range end")

                cursor.restore(start)
                let position = try Expect.notNil(
                    cursor.position(),
                    "cursor current source position"
                )
                try Expect.equal(position.line, 1, "cursor position line")
                try Expect.equal(position.column, 1, "cursor position column")
            }
        }
    }

    static var tokenCodableFlow: TestFlow {
        TestFlow(
            "token-codable",
            tags: ["codable", "lexed-token", "token"]
        ) {
            Step("Token and LexedToken round-trip as durable lexical values") {
                let value = LexedToken(
                    token: .identifier("alpha"),
                    range: PositionRange(
                        uncheckedStart: .init(3),
                        uncheckedEnd: .init(8)
                    )
                )
                let encoded = try JSONEncoder().encode(value)
                let decoded = try JSONDecoder().decode(
                    LexedToken.self,
                    from: encoded
                )

                try Expect.equal(decoded, value, "LexedToken Codable round trip")
            }
        }
    }
}
