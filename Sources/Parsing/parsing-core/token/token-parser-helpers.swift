import Foundation

@inlinable
public func tokenPure<T: Sendable>(
    _ value: T
) -> AnyTokenParser<T> {
    AnyTokenParser { c in
        .success(value, c)
    }
}

@inlinable
public func tokenNoop() -> AnyTokenParser<Void> {
    AnyTokenParser { c in
        .success((), c)
    }
}

@inlinable
public func tokenCut<T: Sendable>(
    _ message: String
) -> AnyTokenParser<T> {
    AnyTokenParser { _ in
        .failure(Diagnostic("[[CUT]] \(message)"))
    }
}
