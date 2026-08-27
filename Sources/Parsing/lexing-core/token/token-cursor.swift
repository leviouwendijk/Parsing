import Foundation
import Position

public struct TokenCursor: Sendable {
    public let tokens: [Token]
    public let lexedTokens: [LexedToken]?
    public let lineTable: LineTable?
    public let filePath: String?
    public var index: Int = 0

    private let legacyLineMap: [Int]?

    public init(
        lexedTokens: [LexedToken],
        source: String? = nil,
        filePath: String? = nil
    ) {
        self.tokens = lexedTokens.map(\.token)
        self.lexedTokens = lexedTokens
        self.lineTable = source.map(LineTable.init(text:))
        self.filePath = filePath
        self.legacyLineMap = nil
    }

    public init(
        lexedTokens: [LexedToken],
        lineTable: LineTable,
        filePath: String? = nil
    ) {
        self.tokens = lexedTokens.map(\.token)
        self.lexedTokens = lexedTokens
        self.lineTable = lineTable
        self.filePath = filePath
        self.legacyLineMap = nil
    }

    @available(
        *,
        deprecated,
        message: "Use init(lexedTokens:source:filePath:) so source provenance is carried by LexedToken rather than a parallel line map."
    )
    public init(
        _ tokens: [Token],
        lineMap: [Int]? = nil,
        filePath: String? = nil
    ) {
        self.tokens = tokens
        self.lexedTokens = nil
        self.lineTable = nil
        self.filePath = filePath
        self.legacyLineMap = lineMap
    }

    @available(
        *,
        deprecated,
        message: "Use lexedTokens and their PositionRange provenance. This is a compatibility view only."
    )
    public var lineMap: [Int]? {
        if let legacyLineMap {
            return legacyLineMap
        }

        guard let lexedTokens, let lineTable else {
            return nil
        }

        return lexedTokens.map {
            lineTable.lineAndColumn(at: $0.range.start.offset).line
        }
    }

    @inlinable
    public var isEOF: Bool {
        index >= tokens.count || tokens[index] == .eof
    }

    @inlinable
    public func peek() -> Token? {
        index < tokens.count ? tokens[index] : nil
    }

    @inlinable
    public mutating func advance() {
        if index < tokens.count {
            index += 1
        }
    }

    @inlinable
    public func mark() -> Int {
        index
    }

    @inlinable
    public mutating func restore(_ mark: Int) {
        index = mark
    }

    public var current: LexedToken? {
        guard let lexedTokens, index < lexedTokens.count else {
            return nil
        }

        return lexedTokens[index]
    }

    public var currentRange: PositionRange? {
        current?.range
    }

    public func sourceRange(from mark: Int) -> PositionRange? {
        guard let lexedTokens, !lexedTokens.isEmpty else {
            return nil
        }

        let lower = min(max(0, mark), lexedTokens.count - 1)
        let upper = min(max(lower, index), lexedTokens.count)

        guard upper > lower else {
            return .point(lexedTokens[lower].range.start)
        }

        return PositionRange(
            uncheckedStart: lexedTokens[lower].range.start,
            uncheckedEnd: lexedTokens[upper - 1].range.end
        )
    }

    public func position(at sourceIndex: PositionIndex) -> Position? {
        if let lineTable {
            return lineTable.position(
                at: sourceIndex,
                file: filePath
            )
        }

        guard let legacyLineMap, !legacyLineMap.isEmpty else {
            return nil
        }

        let tokenIndex = min(max(0, sourceIndex.offset), legacyLineMap.count - 1)

        return Position(
            uncheckedFile: filePath,
            line: legacyLineMap[tokenIndex],
            column: 1,
            invocation: nil
        )
    }

    public func position() -> Position? {
        guard let currentRange else {
            return nil
        }

        return position(at: currentRange.start)
    }

    @available(
        *,
        deprecated,
        message: "Use position(). loc(column:) was line-map based and could not represent exact source columns."
    )
    public func loc(column: Int = 1) -> Position? {
        if let position = position() {
            return position
        }

        guard let legacyLineMap, index < legacyLineMap.count else {
            return nil
        }

        return Position(
            uncheckedFile: filePath,
            line: legacyLineMap[index],
            column: column,
            invocation: nil
        )
    }
}
