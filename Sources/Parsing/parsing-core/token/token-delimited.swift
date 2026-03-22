import Foundation

public enum TokenDelimiter: Sendable, Hashable {
    case none
    case parens
    case brackets
    case braces

    @inlinable
    public func wrap<T: Sendable>(
        _ body: AnyTokenParser<T>
    ) -> AnyTokenParser<T> {
        switch self {
            case .none:
                return body
            case .parens:
                return TokenParsers.parens(body)
            case .brackets:
                return TokenParsers.brackets(body)
            case .braces:
                return TokenParsers.braces(body)
        }
    }
}
