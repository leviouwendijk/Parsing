import Foundation
import Position

public struct TokenCursor: Sendable {
    public let tokens: [Token]
    public let locatedTokens: [LocatedToken]?
    public let textMap: Position.TextMap?
    public let lexedTokens: [LexedToken]?
    public let lineTable: LineTable?
    public let filePath: String?
    public var index: Int = 0

    let legacyLineMap: [Int]?

    init(legacy_tokens: [Token], line_map: [Int]?, filePath: String?) {
        self.tokens = legacy_tokens
        self.locatedTokens = nil
        self.textMap = nil
        self.lexedTokens = nil
        self.lineTable = nil
        self.filePath = filePath
        self.legacyLineMap = line_map
    }

    /// A canonical cursor with mandatory exact UTF-8 provenance.
    public init(
        lexing: LexingResult,
        selection: LexingResult.Selection = .without_spacing,
        filePath: String? = nil
    ) {
        let selected = lexing.select(selection)
        self.tokens = selected.map(\.token)
        self.locatedTokens = selected
        self.textMap = Position.TextMap(source: lexing.source)
        self.lexedTokens = nil
        self.lineTable = nil
        self.filePath = filePath
        self.legacyLineMap = nil
    }

    public init(
        lexedTokens: [LexedToken],
        source: String? = nil,
        filePath: String? = nil
    ) {
        self.tokens = lexedTokens.map(\.token)
        self.lexedTokens = lexedTokens
        self.lineTable = source.map(LineTable.init(text:))
        self.locatedTokens = nil
        self.textMap = source.map(Position.TextMap.init(source:))
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
        self.locatedTokens = nil
        self.textMap = nil
        self.filePath = filePath
        self.legacyLineMap = nil
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
    @discardableResult
    public mutating func restore(_ mark: Int) -> Bool {
        guard mark >= 0, mark <= tokens.count else { return false }
        index = mark
        return true
    }

    public var current: LexedToken? {
        guard let lexedTokens, index < lexedTokens.count else {
            return nil
        }

        return lexedTokens[index]
    }

    public var currentRange: PositionRange? {
        if let textMap, let range = currentUTF8Range {
            return try? textMap.legacyRange(range)
        }
        return current?.range
    }

    /// Construct a failure at the current token without discarding canonical byte provenance.
    public func diagnostic(_ message: String, committed: Bool = false) -> Diagnostic {
        Diagnostic(
            message,
            range: currentRange,
            utf8Range: currentUTF8Range,
            committed: committed
        )
    }

    /// Construct a failure for a consumed token span with exact UTF-8 provenance.
    public func diagnostic(_ message: String, from mark: Int, committed: Bool = false) -> Diagnostic {
        Diagnostic(
            message,
            range: sourceRange(from: mark),
            utf8Range: utf8Range(from: mark),
            committed: committed
        )
    }

    /// Exact UTF-8 projection may be unavailable at grapheme/CRLF boundaries.
    public func position(atUTF8 offset: Position.Offset<Position.Unit.UTF8>) -> Position? {
        guard let textMap,
              let character = try? textMap.convert(offset, to: Position.Unit.Character.self),
              let coordinate = try? textMap.coordinate(at: character) else {
            return nil
        }
        return Position(
            uncheckedFile: filePath,
            line: coordinate.line,
            column: coordinate.column,
            invocation: nil
        )
    }

    public var currentUTF8Range: Range<Position.Offset<Position.Unit.UTF8>>? {
        guard let locatedTokens, index >= 0, index < locatedTokens.count else {
            return current?.utf8Range
        }
        return locatedTokens[index].range
    }

    public func sourceRange(from mark: Int) -> PositionRange? {
        if let textMap, locatedTokens != nil {
            guard let range = utf8Range(from: mark) else { return nil }
            return try? textMap.legacyRange(range)
        }
        guard let lexedTokens, !lexedTokens.isEmpty else {
            return nil
        }

        guard mark >= 0, mark <= index, index <= lexedTokens.count else {
            return nil
        }
        if mark == lexedTokens.count {
            return .point(lexedTokens[lexedTokens.count - 1].range.end)
        }
        if index == mark {
            return .point(lexedTokens[mark].range.start)
        }
        return PositionRange(
            uncheckedStart: lexedTokens[mark].range.start,
            uncheckedEnd: lexedTokens[index - 1].range.end
        )
    }

    /// Exact byte span of consumed lexemes; returns nil when unavailable.
    public func utf8Range(from mark: Int) -> Range<Position.Offset<Position.Unit.UTF8>>? {
        if let locatedTokens {
            guard !locatedTokens.isEmpty, mark >= 0, mark <= index,
                  index <= locatedTokens.count else { return nil }
            if mark == locatedTokens.count {
                let end = locatedTokens[locatedTokens.count - 1].range.upperBound
                return end..<end
            }
            if index == mark {
                let start = locatedTokens[mark].range.lowerBound
                return start..<start
            }
            return locatedTokens[mark].range.lowerBound..<locatedTokens[index - 1].range.upperBound
        }
        guard let lexedTokens, !lexedTokens.isEmpty,
              mark >= 0, mark <= index, index <= lexedTokens.count else {
            return nil
        }
        if mark == lexedTokens.count {
            guard let end = lexedTokens.last?.utf8Range?.upperBound else { return nil }
            return end..<end
        }
        if index == mark {
            guard let start = lexedTokens[mark].utf8Range?.lowerBound else { return nil }
            return start..<start
        }
        guard let start = lexedTokens[mark].utf8Range?.lowerBound,
              let end = lexedTokens[index - 1].utf8Range?.upperBound else {
            return nil
        }
        return start..<end
    }

    public func position(at sourceIndex: PositionIndex) -> Position? {
        if let textMap,
           let offset = try? Position.Offset<Position.Unit.Character>(sourceIndex.offset),
           let coordinate = try? textMap.coordinate(at: offset) {
            return Position(
                uncheckedFile: filePath,
                line: coordinate.line,
                column: coordinate.column,
                invocation: nil
            )
        }
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
        if let textMap, let range = currentUTF8Range,
           let character = try? textMap.convert(range.lowerBound, to: Position.Unit.Character.self),
           let coordinate = try? textMap.coordinate(at: character) {
            return Position(
                uncheckedFile: filePath,
                line: coordinate.line,
                column: coordinate.column,
                invocation: nil
            )
        }
        guard let currentRange else {
            return nil
        }

        return position(at: currentRange.start)
    }


}
