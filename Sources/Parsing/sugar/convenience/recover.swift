import Foundation
import Position

public enum SyncBoundary: Sendable {
    case semicolon, newline, rbrace, rbracket
}

/// Skip invalid tokens until a synchronization boundary or EOF.
/// Success returns the diagnostic and the cursor before the boundary.
/// Callers explicitly decide whether and how to retain the diagnostic.
@inlinable
public func recoverUntil(
    _ boundaries: Set<SyncBoundary>,
    message: String = "skipping invalid input"
) -> AnyTokenParser<Diagnostic> {
    AnyTokenParser<Diagnostic> { cursor in
        var current = cursor
        let mark = cursor.mark()

        while !current.isEOF, let token = current.peek() {
            if (boundaries.contains(.newline) && token.samecase(as: .newline)) ||
               (boundaries.contains(.semicolon) && token.samecase(as: .semicolon)) ||
               (boundaries.contains(.rbrace) && token.samecase(as: .right_brace)) ||
               (boundaries.contains(.rbracket) && token.samecase(as: .right_bracket)) {
                break
            }
            current.advance()
        }

        return .success(
            current.diagnostic(message, from: mark),
            current
        )
    }
}
