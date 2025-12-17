import Foundation

@inlinable
public func sepBy1<T: Sendable>(
    _ item: AnyTokenParser<T>,
    sep: GrammarSeparator
) -> AnyTokenParser<[T]> {
    let s = separator(sep)
    return item.then( s.keep(item).many(min: 0) ).map { first, rest in [first] + rest }
}

// @inlinable
// public func sepEndBy<T: Sendable>(
//     _ item: AnyTokenParser<T>,
//     sep: GrammarSeparator
// ) -> AnyTokenParser<[T]> {
//     let s = separator(sep).optional()
//     return item.then(s).many(min: 0).map { $0.map { $0.0 } }
// }

@inlinable
public func sepEndBy<T: Sendable>(
    _ item: AnyTokenParser<T>,
    sep: GrammarSeparator
) -> AnyTokenParser<[T]> {
    let s = separator(sep)
    let s1 = s.many(min: 1)  // one-or-more separators
    let tail = s1.keep(item).many(min: 0)  // (sep+ item)*
    let trail = s.many(min: 0)  // optional trailing separators
    return item.then(tail).then(trail.optional()).map { pair, _ in
        let (first, rest) = pair
        return [first] + rest
    }
}
