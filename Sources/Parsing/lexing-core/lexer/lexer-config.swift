import Foundation
import Position

public enum LexerErrorStrategy: Sendable {
    case throwing
    case error_token
    case diagnose_only(@Sendable (String, Position) -> Void)
}

public struct LexerConfig: Sendable {
    public var errorStrategy: LexerErrorStrategy = .throwing
    public var unescapeStringsInLexer = true
    
    public init() {}
}
