import Foundation

@inlinable
public func positioned<T: Sendable>(_ inner: AnyTokenParser<T>) -> AnyTokenParser<(T, SourceRange)> {
    AnyTokenParser<(T, SourceRange)> { c in
        let cur = c
        let start = cur.mark()
        switch inner.parse(cur) {
        case .failure(let d): return .failure(d)
        case .success(let v, let next):
            let n = next
            let range = SourceRange(start, n.index)
            return .success((v, range), n)
        }
    }
}
