import Foundation

@inlinable
public func betweenTokens<Inner: Sendable, L: Sendable, R: Sendable>(
    _ left: any TokenParser<L>,
    _ inner: AnyTokenParser<Inner>,
    _ right: any TokenParser<R>
) -> AnyTokenParser<Inner> {
    AnyTokenParser(left).keep(inner).skip(right)
}
