import Foundation

public enum SyncBoundary: Sendable { case semicolon, newline, rbrace, rbracket }

@inlinable
public func recoverUntil(
    _ boundaries: Set<SyncBoundary>,
    message: String = "skipping invalid input"
) -> AnyTokenParser<Void> {
    AnyTokenParser<Void> { c in
        var cur = c
        let start = cur.mark()
        while let t = cur.peek() {
            if (boundaries.contains(.newline)   && t.sameCase(as: .newline)) ||
               (boundaries.contains(.semicolon) && t.sameCase(as: .semicolon)) ||
               (boundaries.contains(.rbrace)    && t.sameCase(as: .right_brace)) ||
               (boundaries.contains(.rbracket)  && t.sameCase(as: .right_bracket)) {
                break
            }
            cur.advance()
        }
        let r = SourceRange(start, cur.index)
        return .failure(Diagnostic(message, range: r))
    }
}
