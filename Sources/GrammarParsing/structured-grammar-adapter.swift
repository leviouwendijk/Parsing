import Parsing
import Position

/// Retains the full canonical grammar tree alongside the legacy flat capture view.
public struct GrammarStructuredResult: Sendable {
    public let root: GrammarParser.Node
    public let match: StructuredParser.Match

    public init(root: GrammarParser.Node, match: StructuredParser.Match) {
        self.root = root
        self.match = match
    }
}

public extension GrammarParser {
    func parseStructured(_ source: String, filePath: String? = nil) throws -> GrammarStructuredResult {
        let root = try parse(source, filePath: filePath)
        return try GrammarStructuredResult(root: root, match: root.structuredMatch(in: source))
    }
}

public extension GrammarParser.Node {
    /// A lossless bridge only for Character-aligned spans; never rounds Unicode boundaries.
    /// `Node` remains the hierarchical representation, including repetitions and productions.
    func structuredMatch(in source: String) throws -> StructuredParser.Match {
        let map = Position.TextMap(source: source)
        var captures: [StructuredParser.Capture] = []

        func appendFields(_ node: GrammarParser.Node) throws {
            if let field = node.field {
                let range = try map.legacyRange(node.range)
                let start = source.index(source.startIndex, offsetBy: range.start.offset)
                let end = source.index(source.startIndex, offsetBy: range.end.offset)
                captures.append(StructuredParser.Capture(
                    name: field,
                    value: String(source[start..<end]),
                    range: range
                ))
            }
            for child in node.children {
                try appendFields(child)
            }
        }

        try appendFields(self)
        return try StructuredParser.Match(range: map.legacyRange(range), captures: captures)
    }
}
