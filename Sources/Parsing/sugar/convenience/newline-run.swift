import Foundation

/// Eats one-or-more newline tokens.
@inlinable
public func newlineRun(min: Int = 1) -> AnyTokenParser<Void> {
    let one = AnyTokenParser(Expect(.newline)).map { (_: Token) in () }
    return one.many(min: max(0, min)).map { _ in () }
}

/// Runs `inner` and then eats any number of trailing newlines.
/// Handy when a value is followed by a visually separated next field.
@inlinable
public func thenAnyNewlines<T: Sendable>(_ inner: AnyTokenParser<T>) -> AnyTokenParser<T> {
    inner.then(newlineRun(min: 0)).map { v, _ in v }
}
