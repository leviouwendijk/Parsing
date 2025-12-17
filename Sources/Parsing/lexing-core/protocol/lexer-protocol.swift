import Foundation

// public enum LexStringBlockMode: Sendable { case none, verbatim, trimmed }

public enum LexStringBlockState: Sendable {
    // case none, awaitingOpen, awaitingContent(LexStringBlockMode), awaitingClose
    case none, awaitingOpen, awaitingContent, awaitingClose
}

public protocol Lexing: Sendable {
    var scalars: [UnicodeScalar] { get }
    var index: Int { get set }
    var line: Int { get set }
    var column: Int { get set }

    var string_block_state: LexStringBlockState { get set }

    mutating func nextToken() -> Token
}
