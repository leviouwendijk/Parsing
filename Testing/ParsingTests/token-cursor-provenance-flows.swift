import Foundation
import Parsing
import Position
import Testing

extension ParsingTestSuite {
    static var tokenCursorProvenanceSuite: TestSuite {
        TestSuite(
            "token-cursor-provenance",
            tags: ["cursor", "position", "range"]
        ) {
            Test("positioned parser returns source characters, not token indices") {
                let source = "💡 alpha"
                var options = Lexer.Options()
                options.unsupported = .skip
                var lexer = Lexer(source: source, sets: .init(keywords: []), options: options)
                let cursor = TokenCursor(lexedTokens: lexer.lexedTokens(), source: source)
                switch positioned(TokenParsers.identifier()).parse(cursor) {
                case .failure(let diagnostic):
                    try Expect.equal(true, false, diagnostic.message)
                case .success(let result, let next):
                    try Expect.equal(result.0, "alpha", "parsed identifier")
                    try Expect.equal(result.1.offsets, 2..<7, "exact Character span")
                    let bytes = try Expect.notNil(next.utf8Range(from: 0), "byte span")
                    try Expect.equal(bytes.lowerBound.offset, 5, "byte start")
                    try Expect.equal(bytes.upperBound.offset, 10, "byte end")
                }
            }

            Test("located token parsing carries exact UTF-8 ranges") {
                let source = "é alpha"
                var lexer = Lexer(source: source, sets: .init(keywords: []))
                let cursor = TokenCursor(lexedTokens: lexer.lexedTokens(), source: source)
                switch TokenParsers.identifier().located().parse(cursor) {
                case .failure(let diagnostic):
                    try Expect.equal(true, false, diagnostic.message)
                case .success(let result, _):
                    try Expect.equal(result.value, "é", "parsed Unicode identifier")
                    try Expect.equal(result.range.lowerBound.offset, 0, "UTF-8 start")
                    try Expect.equal(result.range.upperBound.offset, 2, "UTF-8 end")
                }
                let legacy = LexedToken(
                    token: .identifier("unlocated"),
                    range: PositionRange(uncheckedStart: .init(0), uncheckedEnd: .init(9))
                )
                let eof = LexedToken(
                    token: .eof,
                    range: PositionRange(uncheckedStart: .init(9), uncheckedEnd: .init(9))
                )
                switch TokenParsers.identifier().located().parse(
                    TokenCursor(lexedTokens: [legacy, eof])
                ) {
                case .success:
                    try Expect.equal(true, false, "legacy unlocated cursor must fail")
                case .failure(let diagnostic):
                    try Expect.equal(diagnostic.committed, true, "missing provenance is fatal")
                }
            }

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

                try Expect.equal(cursor.sourceRange(from: -1) == nil, true, "negative mark rejected")
                try Expect.equal(cursor.sourceRange(from: 100) == nil, true, "future mark rejected")
                try Expect.equal(cursor.restore(-1), false, "negative restoration rejected")
                try Expect.equal(cursor.index, 2, "invalid restore leaves position unchanged")
                try Expect.equal(cursor.restore(start), true, "valid restore")
                let position = try Expect.notNil(
                    cursor.position(),
                    "cursor current source position"
                )
                try Expect.equal(position.line, 1, "cursor position line")
                try Expect.equal(position.column, 1, "cursor position column")
            }
        }
    }
}
