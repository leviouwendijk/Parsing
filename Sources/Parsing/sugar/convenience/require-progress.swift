import Foundation

@inlinable
public func requireProgress<T>(_ p: AnyTokenParser<T>) -> AnyTokenParser<T> {
    AnyTokenParser<T> { c in
        let start = c.index
        switch p.parse(c) {
        case .success(let v, let next):
            guard next.index > start else {
                return .failure(Diagnostic(
                    "parser did not advance",
                    range: c.currentRange,
                    committed: true
                ))
            }
            return .success(v, next)
        case .failure(let d):
            return .failure(d)
        }
    }
}
