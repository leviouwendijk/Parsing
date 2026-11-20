import Errors
import Foundation
import Lexing
import Position

/// Errors raised by token-level parsing, independent of lexical analysis.
public enum ParserError: Error {
    case unexpectedToken(Token, expected: String, at: Position)
    case expected(String, at: Position)
}

extension ParserError:
    SemanticError,
    ErrorNamespaced,
    ErrorDispositionProviding
{
    public static let errorNamespace = "parsing"

    public var errorCode: String {
        switch self {
        case .unexpectedToken: return "unexpected_token"
        case .expected: return "expected"
        }
    }

    public var errorPresentation: ErrorPresentation {
        switch self {
        case .unexpectedToken(_, let expected, let at):
            return .init(message: "Unexpected token; expected \(expected) at \(at.line):\(at.column).")
        case .expected(let what, let at):
            return .init(message: "Expected \(what) at \(at.line):\(at.column).")
        }
    }

    public var errorDiagnosticFields: [ErrorDiagnosticField] {
        switch self {
        case .unexpectedToken(_, _, let at), .expected(_, let at):
            return at.errorFields
        }
    }

    /// The source must change.
    public var errorDisposition: ErrorDisposition? {
        .invalid_input
    }
}

extension Diagnostic {
    /// `source.offset`, the UTF-8 offset where the diagnostic starts, for an
    /// error's diagnostics.
    public var errorFields: [ErrorDiagnosticField] {
        guard let offset = utf8Range?.lowerBound.offset ?? range?.start.offset else {
            return []
        }
        return [.init(key: "source.offset", value: offset)]
    }
}
