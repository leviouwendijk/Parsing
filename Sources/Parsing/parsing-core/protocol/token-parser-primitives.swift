import Foundation

// Match exact token kind (by case, ignoring payload).
public struct Expect: TokenParser {
    public typealias Output = Token
    let want: Token
    public init(_ want: Token) { self.want = want }
    public func parse(_ c: TokenCursor) -> TokenParseResult<Token> {
        var cur = c
        guard let t = cur.peek(), t.sameCase(as: want) else {
            return .failure(Diagnostic("expected \(want)"))
        }
        cur.advance()
        return .success(t, cur)
    }
}

// identifier → String
public struct PIdent: TokenParser {
    public typealias Output = String
    public init() {}
    public func parse(_ c: TokenCursor) -> TokenParseResult<String> {
        var cur = c
        guard let t = cur.peek(), case let .identifier(name) = t else {
            return .failure(Diagnostic("expected identifier"))
        }
        cur.advance()
        return .success(name, cur)
    }
}

// keyword(name) → String
public struct PKeyword: TokenParser {
    public typealias Output = String
    let name: String
    public init(_ name: String) { self.name = name }
    public func parse(_ c: TokenCursor) -> TokenParseResult<String> {
        var cur = c
        guard let t = cur.peek(), case let .keyword(k) = t, k == name else {
            return .failure(Diagnostic("expected keyword '\(name)'"))
        }
        cur.advance()
        return .success(name, cur)
    }
}

// number → Decimal
public struct PNumber: TokenParser {
    public typealias Output = Decimal
    public init() {}
    public func parse(_ c: TokenCursor) -> TokenParseResult<Decimal> {
        var cur = c
        guard let t = cur.peek(), case let .number(n, _) = t else {
            return .failure(Diagnostic("expected number"))
        }
        cur.advance()
        return .success(n, cur)
    }
}

// string → String (both quoted or block-parsed strings arrive as .string payload)
public struct PString: TokenParser {
    public typealias Output = String
    public init() {}
    public func parse(_ c: TokenCursor) -> TokenParseResult<String> {
        var cur = c
        guard let t = cur.peek(), case let .string(s) = t else {
            return .failure(Diagnostic("expected string"))
        }
        cur.advance()
        return .success(s, cur)
    }
}

// date_literal → String (keep as-is for now)
public struct PDate: TokenParser {
    public typealias Output = String
    public init() {}
    public func parse(_ c: TokenCursor) -> TokenParseResult<String> {
        var cur = c
        guard let t = cur.peek(), case let .date_literal(d) = t else {
            return .failure(Diagnostic("expected date literal"))
        }
        cur.advance()
        return .success(d, cur)
    }
}
