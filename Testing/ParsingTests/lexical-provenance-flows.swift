import Foundation
import Parsing
import Position
import Testing

extension ParsingTestSuite {
    static var lexicalProvenanceSuite: TestSuite {
        TestSuite(
            "lexical-provenance",
            tags: ["lexer", "position", "unicode"]
        ) {
            Test("positioned lexing uses Character offsets and excludes skipped trivia") {
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

            Test("identifier continuation policy preserves defaults and can expose punctuation") {
                let source = "foo.bar foo-bar"

                var defaultLexer = Lexer(
                    source: source,
                    sets: LexingSets(keywords: [])
                )
                let defaultTokens = defaultLexer.lexedTokens().map(\.token)

                var punctuationOptions = LexerOptions()
                punctuationOptions.identifier_continuation = .punctuation_delimited

                var punctuationLexer = Lexer(
                    source: source,
                    sets: LexingSets(keywords: []),
                    options: punctuationOptions
                )
                let punctuationTokens = punctuationLexer.lexedTokens().map(\.token)

                try Expect.equal(
                    defaultTokens,
                    [
                        .identifier("foo.bar"),
                        .identifier("foo-bar"),
                        .eof,
                    ],
                    "default identifier continuation remains dotted and hyphenated"
                )
                try Expect.equal(
                    punctuationTokens,
                    [
                        .identifier("foo"),
                        .dot,
                        .identifier("bar"),
                        .identifier("foo"),
                        .dash,
                        .identifier("bar"),
                        .eof,
                    ],
                    "punctuation-delimited identifiers expose dot and dash tokens"
                )
            }
        }
    }

    static var tokenCursorProvenanceSuite: TestSuite {
        TestSuite(
            "token-cursor-provenance",
            tags: ["cursor", "position", "range"]
        ) {
            Test("cursor preserves token ergonomics while deriving exact source ranges") {
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

    static var tokenCodableSuite: TestSuite {
        TestSuite(
            "token-codable",
            tags: ["codable", "lexed-token", "token"]
        ) {
            Test("Token and LexedToken round-trip as durable lexical values") {
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
