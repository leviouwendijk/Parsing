import Foundation

// Token sugar
public enum TokenParsers {
    // === atoms ===
    public static func keyword(_ k: Keyword) -> AnyTokenParser<Void> {
        switch k {
        case .raw(let name):
            return AnyTokenParser(PKeyword(name)).map { (_: String) in () }
        }
    }

    public static func identifier() -> AnyTokenParser<String> {
        AnyTokenParser(PIdent())
    }

    /// a.b.c via tokens: ident ('.' ident)*
    public static func dotPath() -> AnyTokenParser<String> {
        let head = identifier()
        let dot  = AnyTokenParser(Expect(.dot)).map { (_: Token) in () }
        let tail = dot.then(identifier())
            .map { _, name in "." + name }
            .many(min: 0)
            .map { parts in parts.joined() }

        return head.flatMap { h in tail.map { h + $0 } }
    }

    public static func number() -> AnyTokenParser<Decimal> {
        AnyTokenParser(PNumber())
    }

    public static func string() -> AnyTokenParser<String> {
        AnyTokenParser(PString())
    }

    // === delimiters ===

    /// between '(' and ')'
    public static func parens<T: Sendable>(_ inner: AnyTokenParser<T>) -> AnyTokenParser<T> {
        betweenTokens(Expect(.left_parenthesis), inner, Expect(.right_parenthesis))
    }

    /// between '{' and '}'
    public static func braces<T: Sendable>(_ inner: AnyTokenParser<T>) -> AnyTokenParser<T> {
        betweenTokens(Expect(.left_brace), inner, Expect(.right_brace))
    }

    /// between '[' and ']'
    public static func brackets<T: Sendable>(_ inner: AnyTokenParser<T>) -> AnyTokenParser<T> {
        betweenTokens(Expect(.left_bracket), inner, Expect(.right_bracket))
    }

    static func angles<T: Sendable>(_ inner: AnyTokenParser<T>) -> AnyTokenParser<T> {
        betweenTokens(Expect(.less_than), inner, Expect(.greater_than))
    }
}
