import Foundation
import Position
import Primitives

/// Translation at the syntax/semantic boundary. Diagnostics are still ordinary parse
/// diagnostics; failure codes and semantic paths are rendered rather than discarded.
private enum InvariantParseFailure {
    static func message(for error: any Swift.Error) -> String {
        guard let failure = error as? InvarianceFailure else {
            return (error as? LocalizedError)?.errorDescription
                ?? String(describing: error)
        }
        return failure.violations.map { violation in
            let path = violation.path.map { component in
                switch component {
                case .field(let name): return ".\(name)"
                case .index(let number): return "[\(number)]"
                }
            }.joined()
            return "\(violation.code)\(path.isEmpty ? "" : " at " + path): \(violation.message)"
        }.joined(separator: "; ")
    }
}

public extension Parser {
    /// Transform parsed output with a potentially throwing semantic operation.
    /// Once the upstream parser has succeeded, a transformation error is committed.
    func tryMap<U: Sendable>(
        _ transform: @Sendable @escaping (Output) throws -> U
    ) -> AnyParser<U> {
        AnyParser<U> { cursor in
            switch self.parse(cursor) {
            case .failure(let diagnostic):
                return .failure(diagnostic)
            case .success(let value, let next):
                do {
                    return .success(try transform(value), next)
                } catch {
                    return .failure(
                        Diagnostic(
                            InvariantParseFailure.message(for: error),
                            range: PositionRange(
                                uncheckedStart: .init(cursor.offset),
                                uncheckedEnd: .init(next.offset)
                            ),
                            committed: true
                        )
                    )
                }
            }
        }
    }

    /// Apply a contextual rule set without changing the parser's output type.
    func validated(by rules: Invariance<Output>) -> AnyParser<Output> {
        tryMap { value in
            try rules.require(value)
            return value
        }
    }

    /// Construct an intrinsically guaranteed value from the parsed raw representation.
    func invariant<Value: Invariant & Sendable>(
        _ type: Value.Type
    ) -> AnyParser<Value> where Value.Raw == Output {
        tryMap { try Value($0) }
    }
}

public extension TokenParser {
    /// Transform parsed tokens with a throwing, committed semantic operation.
    func tryMap<U: Sendable>(
        _ transform: @Sendable @escaping (Output) throws -> U
    ) -> AnyTokenParser<U> {
        AnyTokenParser<U> { cursor in
            switch self.parse(cursor) {
            case .failure(let diagnostic):
                return .failure(diagnostic)
            case .success(let value, let next):
                do {
                    return .success(try transform(value), next)
                } catch {
                    return .failure(
                        Diagnostic(
                            InvariantParseFailure.message(for: error),
                            range: next.sourceRange(from: cursor.index)
                                ?? cursor.currentRange,
                            committed: true
                        )
                    )
                }
            }
        }
    }

    func validated(by rules: Invariance<Output>) -> AnyTokenParser<Output> {
        tryMap { value in
            try rules.require(value)
            return value
        }
    }

    func invariant<Value: Invariant & Sendable>(
        _ type: Value.Type
    ) -> AnyTokenParser<Value> where Value.Raw == Output {
        tryMap { try Value($0) }
    }
}
