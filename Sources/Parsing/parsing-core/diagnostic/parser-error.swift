import Foundation
import Lexing
import Position

/// Errors raised by token-level parsing, independent of lexical analysis.
public enum ParserError: Error, LocalizedError {
    case unexpectedToken(Token, expected: String, at: Position)
    case expected(String, at: Position)

    public var errorDescription: String? {
        switch self {
        case .unexpectedToken(_, let expected, let at):
            return "Unexpected token; expected \(expected) at \(at.line):\(at.column)."
        case .expected(let what, let at):
            return "Expected \(what) at \(at.line):\(at.column)."
        }
    }
}
