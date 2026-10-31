import Foundation
import Parsing
import Primitives
import Testing

private struct NonzeroDigit: Invariant, Sendable {
    enum Error: Swift.Error, LocalizedError, Sendable {
        case zero
        var errorDescription: String? { "digit must be nonzero" }
    }
    let value: String
    init(_ raw: String) throws(Error) {
        guard raw != "0" else { throw .zero }
        value = raw
    }
}

private struct NamedCode: Invariant, Sendable {
    enum Error: Swift.Error, LocalizedError, Sendable {
        case tooShort
        var errorDescription: String? { "code must have at least three characters" }
    }
    let value: String
    init(_ raw: String) throws(Error) {
        guard raw.count >= 3 else { throw .tooShort }
        value = raw
    }
}

private func tokenCursor(_ token: Token, source: String) -> TokenCursor {
    TokenCursor(
        lexedTokens: [
            .init(
                token: token,
                range: .init(uncheckedStart: .init(0), uncheckedEnd: .init(source.count))
            ),
            .init(token: .eof, range: .point(source.count)),
        ],
        source: source
    )
}

func test_parsing_invariant_character() throws {
    let parser = ExpectString("abc").invariant(NamedCode.self)
    switch parser.parse(Cursor("abc")) {
    case .success(let value, let next):
        try Expect.true(value.value == "abc" && next.isEOF, "guaranteed character output")
    case .failure(let d):
        try Expect.true(false, "unexpected character failure: \(d)")
    }

    let failing = ExpectString("ab").invariant(NamedCode.self)
    switch failing.parse(Cursor("ab")) {
    case .success:
        try Expect.true(false, "invalid semantic output must fail")
    case .failure(let d):
        try Expect.true(d.committed, "semantic failure committed")
        try Expect.true(d.message.contains("at least three"), "typed error explanation")
        try Expect.true(d.range?.start.offset == 0 && d.range?.end.offset == 2, "consumed character range")
    }
}

func test_parsing_invariance_rules() throws {
    let rules = Invariance<String>([.length.min(3), .text.nonblank])
    let parser = Remainder().validated(by: rules)
    switch parser.parse(Cursor("abc")) {
    case .success(let value, _): try Expect.true(value == "abc", "validated retains raw value")
    case .failure: try Expect.true(false, "valid rule value accepted")
    }
    switch parser.parse(Cursor(" ")) {
    case .success: try Expect.true(false, "multiple failed rules must reject")
    case .failure(let d):
        try Expect.true(d.committed, "validation failure committed")
        try Expect.true(d.message.contains("length_below_minimum"), "first code preserved")
        try Expect.true(d.message.contains("blank_text"), "second code preserved")
    }
}

func test_parsing_character_commitment() throws {
    let plain = ExpectString("z").orElse(ExpectString("a"))
    switch plain.parse(Cursor("a")) {
    case .success(let value, _): try Expect.true(value == "a", "recoverable alternative")
    case .failure: try Expect.true(false, "recoverable mismatch should fall back")
    }

    let committed = ExpectString("z").cut().orElse(ExpectString("a"))
    switch committed.parse(Cursor("a")) {
    case .success: try Expect.true(false, "cut forbids alternative")
    case .failure(let d): try Expect.true(d.committed, "cut metadata preserved")
    }
    switch ExpectString("z").cut().optional().parse(Cursor("a")) {
    case .success: try Expect.true(false, "optional must not swallow cut")
    case .failure(let d): try Expect.true(d.committed, "optional propagates cut")
    }
    switch ExpectString("z").optional().parse(Cursor("a")) {
    case .success(let value, let next): try Expect.true(value == nil && next.offset == 0, "recoverable absence")
    case .failure: try Expect.true(false, "optional recoverable")
    }
    switch ExpectString("z").cut().withBacktracking().orElse(ExpectString("a")).parse(Cursor("a")) {
    case .success(let value, _): try Expect.true(value == "a", "backtracking clears commitment")
    case .failure: try Expect.true(false, "explicit backtracking allows fallback")
    }
}

func test_parsing_character_repetition() throws {
    let digits = Char(where: { $0.isNumber }).map { String($0) }.invariant(NonzeroDigit.self)
    switch digits.many().parse(Cursor("10")) {
    case .success: try Expect.true(false, "repetition must not discard invalid second value")
    case .failure(let d): try Expect.true(d.committed, "repetition propagates semantic failure")
    }
    switch digits.many().parse(Cursor("1x")) {
    case .success(let values, let next):
        try Expect.true(values.count == 1 && next.offset == 1, "recoverable stop")
    case .failure: try Expect.true(false, "unmatched character terminates repetition")
    }
    switch OptionalP(ExpectString("z").cut()).parse(Cursor("a")) {
    case .success: try Expect.true(false, "concrete OptionalP must preserve commitment")
    case .failure: break
    }
    switch Many(ExpectString("z").cut(), min: 0).parse(Cursor("a")) {
    case .success: try Expect.true(false, "concrete Many must preserve commitment")
    case .failure: break
    }
}

func test_parsing_token_bridge_and_commitment() throws {
    let good = tokenCursor(.identifier("abc"), source: "abc")
    switch PIdent().invariant(NamedCode.self).parse(good) {
    case .success(let value, let next): try Expect.true(value.value == "abc" && next.index == 1, "typed token output")
    case .failure: try Expect.true(false, "valid token invariant")
    }
    let bad = tokenCursor(.identifier("ab"), source: "ab")
    let semantic = PIdent().invariant(NamedCode.self)
    switch semantic.parse(bad) {
    case .success: try Expect.true(false, "invalid token invariant must reject")
    case .failure(let d):
        try Expect.true(d.committed, "token semantic rejection committed")
        try Expect.true(d.range?.start.offset == 0 && d.range?.end.offset == 2, "token source range")
    }
    switch semantic.optional().parse(bad) {
    case .success: try Expect.true(false, "token optional must not swallow semantic error")
    case .failure(let d): try Expect.true(d.committed, "token optional propagates")
    }
    switch semantic.many().parse(bad) {
    case .success: try Expect.true(false, "token many must not swallow semantic error")
    case .failure(let d): try Expect.true(d.committed, "token many propagates")
    }

    let recovered = PKeyword("key").withBacktracking().orElse(PIdent())
    switch recovered.parse(bad) {
    case .success(let value, _): try Expect.true(value == "ab", "token alternative works")
    case .failure: try Expect.true(false, "token alternative failed")
    }
    switch PKeyword("key").cut().orElse(PIdent()).parse(bad) {
    case .success: try Expect.true(false, "token cut forbids alternative")
    case .failure(let d):
        try Expect.true(d.committed && !d.message.contains("[[CUT]]"), "commitment is structural")
    }
    let abort: AnyTokenParser<String> = tokenCut("abort")
    switch abort.optional().parse(bad) {
    case .success: try Expect.true(false, "tokenCut cannot be swallowed by optional")
    case .failure(let d): try Expect.true(d.committed && d.message == "abort", "helper commitment")
    }
}

func test_parsing_token_rules_and_helpers() throws {
    let nonnegative = Invariance<Decimal>([.decimal.finite, .number.nonnegative])
    let good = tokenCursor(.number(5, raw: "5"), source: "5")
    switch PNumber().validated(by: nonnegative).parse(good) {
    case .success(let value, _): try Expect.true(value == 5, "numeric token validation")
    case .failure: try Expect.true(false, "valid positive number")
    }
    let bad = tokenCursor(.number(-1, raw: "-1"), source: "-1")
    switch PNumber().validated(by: nonnegative).parse(bad) {
    case .success: try Expect.true(false, "negative number must fail rules")
    case .failure(let d): try Expect.true(d.committed && d.message.contains("number.nonnegative"), "numeric rule code")
    }
    switch PKeyword("missing").cut().withBacktracking().orElse(PIdent()).parse(
        tokenCursor(.identifier("ok"), source: "ok")
    ) {
    case .success(let value, _): try Expect.true(value == "ok", "token explicit backtracking")
    case .failure: try Expect.true(false, "backtracking should clear cut")
    }
}

func test_parsing_progress_guards() throws {
    let noProgress = AnyParser<Int> { cursor in .success(1, cursor) }
    switch noProgress.many().parse(Cursor("x")) {
    case .success: try Expect.true(false, "character repetition must reject zero progress")
    case .failure(let d): try Expect.true(d.message.contains("did not consume"), "character progress diagnostic")
    }
    let tokenNoProgress = AnyTokenParser<Int> { cursor in .success(1, cursor) }
    switch tokenNoProgress.many().parse(tokenCursor(.identifier("x"), source: "x")) {
    case .success: try Expect.true(false, "token repetition must reject zero progress")
    case .failure(let d): try Expect.true(d.message.contains("did not consume"), "token progress diagnostic")
    }
}

func test_parsing_diagnostic_coding() throws {
    let committed = Diagnostic("bad", committed: true)
    let encoded = try JSONEncoder().encode(committed)
    let decoded = try JSONDecoder().decode(Diagnostic.self, from: encoded)
    try Expect.true(decoded.committed && decoded.message == "bad", "commitment survives coding")

}


extension ParsingTestSuite {
    static var parserInvarianceSuite: TestSuite {
        TestSuite(
            "parser-invariance",
            title: "Parser invariant and commitment tests",
            tags: ["parsing", "invariance"]
        ) {
            Test("character-invariant", tags: ["invariant"]) {
                try test_parsing_invariant_character()
            }
            Test("character-invariance-rules", tags: ["invariance"]) {
                try test_parsing_invariance_rules()
            }
            Test("character-commitment", tags: ["commitment"]) {
                try test_parsing_character_commitment()
            }
            Test("character-repetition", tags: ["commitment"]) {
                try test_parsing_character_repetition()
            }
            Test("token-invariant-commitment", tags: ["invariant", "commitment"]) {
                try test_parsing_token_bridge_and_commitment()
            }
            Test("token-invariance-rules", tags: ["invariance"]) {
                try test_parsing_token_rules_and_helpers()
            }
            Test("progress-guards", tags: ["parsing"]) {
                try test_parsing_progress_guards()
            }
            Test("diagnostic-coding", tags: ["diagnostics"]) {
                try test_parsing_diagnostic_coding()
            }
        }
    }
}
