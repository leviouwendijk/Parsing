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
            guard let range = next.sourceRange(from: start) else {
                return .failure(Diagnostic(
                    "Source provenance unavailable for positioned parser",
                    committed: true
                ))
            }
            return .success((v, range), next)
        }
    }
}
