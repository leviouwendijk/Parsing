import Foundation
import Position

public enum SyntaxNode: Sendable {
    case atom(String)
    case number(Decimal)
    case boolean(Bool)
    case string(String)
    case map([String: SyntaxNode])
    case list([SyntaxNode])
    case unknown(PositionRange)
}
