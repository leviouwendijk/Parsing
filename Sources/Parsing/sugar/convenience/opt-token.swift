import Foundation

/// Consume an optional **specific** token (matched by `.sameCase(as:)`) before `inner`.
@inlinable
public func optToken<T: Sendable>(
    _ want: Token,
    then inner: AnyTokenParser<T>
) -> AnyTokenParser<T> {
    AnyTokenParser<T> { ctx in
        var n = ctx
        if let t = n.peek(), t.sameCase(as: want) { n.advance() }
        return inner.parse(n)
    }
}

/// Consume an optional token that matches a predicate before `inner`.
/// Useful for payload-carrying cases (e.g. `.keyword("foo")`).
@inlinable
public func optTokenWhere<T: Sendable>(
    _ predicate: @escaping @Sendable (Token) -> Bool,
    then inner: AnyTokenParser<T>
) -> AnyTokenParser<T> {
    AnyTokenParser<T> { ctx in
        var n = ctx
        if let t = n.peek(), predicate(t) { n.advance() }
        return inner.parse(n)
    }
}

/// Shorthand: consume an optional '=' before `inner`.
@inlinable
public func optEquals<T: Sendable>(
    then inner: AnyTokenParser<T>
) -> AnyTokenParser<T> {
    optToken(.equals, then: inner)
}
