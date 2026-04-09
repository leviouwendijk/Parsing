import Foundation
import Position

@inlinable
public func positioned<T: Sendable>(_ inner: AnyTokenParser<T>) -> AnyTokenParser<(T, PositionRange)> {
    AnyTokenParser<(T, PositionRange)> { c in
        let cur = c
        let start = cur.mark()
        switch inner.parse(cur) {
        case .failure(let d): return .failure(d)
        case .success(let v, let next):
            let n = next
            let range = PositionRange(
                uncheckedStart: .init(start),
                uncheckedEnd: .init(n.index)
            )

            return .success((v, range), n)
        }
    }
}
