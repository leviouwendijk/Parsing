import Foundation

public enum LexerError: Error, LocalizedError {
    case unexpectedEOF(context: String, at: SourceLocation)
    case unterminated(delimiter: String, at: SourceLocation)
    case invalidEscape(sequence: String, at: SourceLocation)
    case invalidNumber(raw: String, at: SourceLocation)
    case emptyIdentifier(at: SourceLocation)
    case invalidDateLiteral(raw: String, at: SourceLocation)
    case message(String, at: SourceLocation)

    public var errorDescription: String? {
        switch self {
        case .unexpectedEOF(let ctx, let at):
            return "Unexpected end of input while reading \(ctx) at \(at.line):\(at.column)."
        case .unterminated(let d, let at):
            return "Unterminated block; expected closing \(d) at \(at.line):\(at.column)."
        case .invalidEscape(let seq, let at):
            return "Invalid escape sequence \\\(seq) at \(at.line):\(at.column)."
        case .invalidNumber(let raw, let at):
            return "Invalid number '\(raw)' at \(at.line):\(at.column)."
        case .emptyIdentifier(let at):
            return "Expected identifier at \(at.line):\(at.column)."
        case .invalidDateLiteral(let raw, let at):
            return "Invalid date literal '\(raw)' at \(at.line):\(at.column)."
        case .message(let m, let at): 
            return "\(m) at \(at.line):\(at.column)" 
        }
    }
}

/// Optional: for token-level parsing helpers
public enum ParserError: Error, LocalizedError {
    case unexpectedToken(Token, expected: String, at: SourceLocation)
    case expected(String, at: SourceLocation)
    public var errorDescription: String? {
        switch self {
        case .unexpectedToken(_, let expected, let at):
            return "Unexpected token; expected \(expected) at \(at.line):\(at.column)."
        case .expected(let what, let at):
            return "Expected \(what) at \(at.line):\(at.column)."
        }
    }
}
