import Lexing

public extension Delimiter {
    /// Character-level recognition of an arbitrary balanced delimiter pair.
    /// Pass `escape` when the language permits escaping a closing delimiter.
    func parser(escape: Character? = nil) -> AnyParser<String> {
        AnyParser<String> { origin in
            var cursor = origin

            func consume(_ literal: String, from cursor: inout Cursor) -> Bool {
                var probe = cursor
                for character in literal {
                    guard probe.peek() == character else { return false }
                    probe.advance()
                }
                cursor = probe
                return true
            }

            guard !start.isEmpty, !end.isEmpty, consume(start, from: &cursor) else {
                return .failure(Diagnostic("Expected opening delimiter '\(start)'"))
            }

            let bodyStart = cursor.index
            var depth = 1
            while !cursor.isEOF {
                let boundary = cursor.index
                if let escape, cursor.peek() == escape {
                    cursor.advance()
                    if !cursor.isEOF { cursor.advance() }
                    continue
                }
                if consume(end, from: &cursor) {
                    depth -= 1
                    if depth == 0 {
                        return .success(String(cursor.input[bodyStart..<boundary]), cursor)
                    }
                    continue
                }
                if allowsNesting && consume(start, from: &cursor) {
                    depth += 1
                    continue
                }
                cursor.advance()
            }
            return .failure(Diagnostic(
                "Unterminated delimiter; expected '\(end)'",
                range: cursor.range(from: origin.index),
                committed: true
            ))
        }
    }
}
