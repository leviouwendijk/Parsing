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
            Test("canonical atom failure carries exact UTF-8 diagnostics") {
                let source = "é  alpha\r\n"
                let spec = try Lexer.Specification(vocabulary: .init(keywords: []))
                let cursor = TokenCursor(lexing: try spec.lex(source))
                switch TokenParsers.number().parse(cursor) {
                case .success:
                    try Expect.true(false, "number parser must fail on an identifier")
                case .failure(let diagnostic):
                    try Expect.equal(diagnostic.utf8Range?.lowerBound.offset, 0, "byte start")
                    try Expect.equal(diagnostic.utf8Range?.upperBound.offset, 2, "byte end")
                    try Expect.true(diagnostic.render(using: cursor).contains("@"), "location is rendered")
                }
            }
            Test("a committed token failure retains its original UTF-8 interval") {
                let source = "é  alpha"
                let spec = try Lexer.Specification(vocabulary: .init(keywords: []))
                let cursor = TokenCursor(lexing: try spec.lex(source))
                let parser = TokenParsers.number().cut()
                switch parser.parse(cursor) {
                case .success:
                    try Expect.true(false, "number parser must fail")
                case .failure(let diagnostic):
                    try Expect.true(diagnostic.committed, "cut commits failure")
                    try Expect.equal(diagnostic.utf8Range?.lowerBound.offset, 0, "byte start preserved")
                    try Expect.equal(diagnostic.utf8Range?.upperBound.offset, 2, "byte end preserved")
                }
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
