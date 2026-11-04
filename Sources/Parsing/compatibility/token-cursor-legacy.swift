import Position

extension TokenCursor {
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
        self.init(legacy_tokens: tokens, line_map: lineMap, filePath: filePath)
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
