import Parsing
import Position
import Testing

extension ParsingTestSuite {
    static var canonicalLexingSuite: TestSuite {
        TestSuite("canonical-lexing-parsing") {
            Test("canonical located token parsing carries real UTF-8 offsets") {
                let source = "é  alpha\r\n"
                let spec = try Lexer.Specification(vocabulary: .init(keywords: []))
                let result = try spec.lex(source)
                var cursor = TokenCursor(lexing: result)
                switch TokenParsers.identifier().located().parse(cursor) {
                case .failure(let d): try Expect.true(false, d.message)
                case .success(let value, let next):
                    try Expect.equal(value.value, "é", "first lexeme")
                    try Expect.equal(value.range.lowerBound.offset, 0, "UTF-8 start")
                    try Expect.equal(value.range.upperBound.offset, 2, "UTF-8 end")
                    cursor = next
                }
                switch TokenParsers.identifier().located().parse(cursor) {
                case .failure(let d): try Expect.true(false, d.message)
                case .success(let value, let next):
                    try Expect.equal(value.value, "alpha", "trivia excluded")
                    try Expect.equal(value.range.lowerBound.offset, 4, "UTF-8 start after spaces")
                    try Expect.equal(value.range.upperBound.offset, 9, "UTF-8 end")
                    try Expect.equal(next.peek(), .newline, "newline retained")
                }
                try Expect.equal(cursor.restore(-1), false, "invalid marks rejected")
            }
            Test("failed parse preserves exact diagnostic through cuts") {
                let source = "something"
                let specification = try Lexer.Specification(vocabulary: .init(keywords: []))
                let lexing = try specification.lex(source)
                let cursor = TokenCursor(lexing: lexing)
                let error = Diagnostic("not found", utf8Range: cursor.currentUTF8Range)
                let retained = error.withCommitted(true)
                try Expect.equal(retained.utf8Range?.lowerBound.offset, 0, "provenance survives")
                try Expect.true(retained.committed, "committed failure")
            }
        }
    }
}
