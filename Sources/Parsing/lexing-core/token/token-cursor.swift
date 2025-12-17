import Foundation

// Sources/Parsers/lexing-core/token/token-cursor.swift
public struct TokenCursor: Sendable {
    public let tokens: [Token]
    public let lineMap: [Int]?     // 1-based line for tokens[index]
    public let filePath: String?

    public var index: Int = 0

    public init(_ tokens: [Token], lineMap: [Int]? = nil, filePath: String? = nil) {
        self.tokens = tokens
        self.lineMap = lineMap
        self.filePath = filePath
    }

    @inlinable public var isEOF: Bool { index >= tokens.count || tokens[index] == .eof }
    @inlinable public func peek() -> Token? { index < tokens.count ? tokens[index] : nil }
    @inlinable public mutating func advance() { if index < tokens.count { index += 1 } }
    @inlinable public func mark() -> Int { index }
    @inlinable public mutating func restore(_ m: Int) { index = m }

    // New: provide a SourceLocation for *current* token (column=1 fallback).
    public func loc(column: Int = 1) -> SourceLocation? {
        guard let lm = lineMap, index < lm.count else { return nil }
        return SourceLocation(file: filePath, line: lm[index], column: column, invocation: nil)
    }
}
