import Errors
import Lexing
import Parsing

extension GrammarParser.Failure:
    SemanticError,
    ErrorNamespaced,
    ErrorDispositionProviding
{
    public static let errorNamespace = "parsing.grammar"

    public var errorCode: String {
        switch self {
        case .unsupported_left_recursion: return "unsupported_left_recursion"
        case .unsupported_precedence: return "unsupported_precedence"
        case .lexical: return "lexical"
        case .syntax: return "syntax"
        }
    }

    public var errorPresentation: ErrorPresentation {
        switch self {
        case .unsupported_left_recursion(let name):
            return .init(
                message: "The production '\(name)' is left-recursive, which the native parser does not support.",
                recoverySuggestion: "Rewrite it as a repetition."
            )
        case .unsupported_precedence:
            return .init(
                message: "The grammar declares precedence, which the native parser does not support."
            )
        case .lexical(let diagnostic):
            return .init(
                message: "The source holds text no token matches.",
                // Diagnostics may quote the source.
                reason: diagnostic.message,
                reasonSensitivity: .potentially_sensitive
            )
        case .syntax(let diagnostic):
            return .init(
                message: "The source does not parse.",
                reason: diagnostic.message,
                reasonSensitivity: .potentially_sensitive
            )
        }
    }

    public var errorDiagnosticFields: [ErrorDiagnosticField] {
        switch self {
        case .unsupported_left_recursion(let name):
            return [.init(key: "grammar.symbol", value: name)]
        case .unsupported_precedence:
            return []
        case .lexical(let diagnostic):
            return [.init(key: "source.offset", value: diagnostic.range.lowerBound.offset)]
        case .syntax(let diagnostic):
            return diagnostic.errorFields
        }
    }

    public var errorDisposition: ErrorDisposition? {
        switch self {
        case .unsupported_left_recursion, .unsupported_precedence:
            return .permanent
        case .lexical, .syntax:
            return .invalid_input
        }
    }
}
