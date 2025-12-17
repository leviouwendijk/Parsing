import Foundation

public struct Char: Parser {
    public typealias Output = Character
    let predicate: @Sendable (Character)->Bool
    let want: String

    public init(where predicate: @Sendable @escaping (Character)->Bool, want: String = "character") {
        self.predicate = predicate; self.want = want
    }

    public func parse(_ c: Cursor) -> ParseResult<Character> {
        var cur = c
        guard let ch = cur.peek(), predicate(ch) else {
            return .failure(Diagnostic("expected \(want)", range: SourceRange(c.offset, c.offset)))
        }
        cur.advance()
        return .success(ch, cur)
    }
}

public struct ExpectString: Parser {
    public typealias Output = String
    let literal: String
    public init(_ s: String) { self.literal = s }
    public func parse(_ c: Cursor) -> ParseResult<String> {
        var cur = c
        let start = cur.index
        for want in literal {
            guard let ch = cur.peek(), ch == want else {
                return .failure(Diagnostic("expected \"\(literal)\"", range: cur.range(from: start)))
            }
            cur.advance()
        }
        return .success(literal, cur)
    }
}

public func whitespace() -> AnyParser<Void> {
    AnyParser<Void> { c in
        var cur = c
        let start = cur.index
        cur.skipWhitespace()
        return .success((), (cur.index == start) ? c : cur)
    }
}

public func identifier() -> AnyParser<String> {
    // letters [letters|digits|_]*
    let head: AnyParser<String> =
        Char(where: { $0.isLetter }, want: "identifier head")
            .map { ch in String(ch) }    // Character -> String

    let tail: AnyParser<String> =
        Many(
            Char(where: { $0.isLetter || $0.isNumber || $0 == "_" },
                 want: "identifier tail"),
            min: 0
        )
        .map { chars in String(chars) }  // [Character] -> String

    return head.flatMap { h in
        tail.map { t in h + t }          // concatenate
    }
}

public extension Parser {
    @inlinable
    func flatMap<U>(_ f: @Sendable @escaping (Output) -> any Parser<U>) -> AnyParser<U> {
        let a = AnyParser(self)
        return AnyParser<U> { c in
            switch a.parse(c) {
            case .failure(let d):           return .failure(d)
            case .success(let o, let next): return AnyParser(f(o)).parse(next)
            }
        }
    }
}
