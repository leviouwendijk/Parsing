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
            if (boundaries.contains(.newline) && token.sameCase(as: .newline)) ||
               (boundaries.contains(.semicolon) && token.sameCase(as: .semicolon)) ||
               (boundaries.contains(.rbrace) && token.sameCase(as: .right_brace)) ||
               (boundaries.contains(.rbracket) && token.sameCase(as: .right_bracket)) {
                break
            }
            current.advance()
        }

        return .success(
            Diagnostic(message, range: current.sourceRange(from: mark)),
            current
        )
    }
}
