import Position

/// A parsed value with its exact consumed UTF-8 span.
public struct LocatedParse<Output: Sendable>: Sendable {
    public let value: Output
    public let range: Range<Position.Offset<Position.Unit.UTF8>>

    public init(value: Output, range: Range<Position.Offset<Position.Unit.UTF8>>) {
        self.value = value
        self.range = range
    }
}

public extension TokenParser {
    /// Requires source-backed lexemes; rejects unlocated compatibility cursors.
    func located() -> AnyTokenParser<LocatedParse<Output>> {
        AnyTokenParser { cursor in
            switch self.parse(cursor) {
            case .failure(let diagnostic):
                return .failure(diagnostic)
            case .success(let value, let next):
                guard let range = next.utf8Range(from: cursor.index) else {
                    return .failure(Diagnostic(
                        "parsed value lacks exact UTF-8 provenance",
                        range: next.currentRange,
                        utf8Range: next.currentUTF8Range,
                        committed: true
                    ))
                }
                return .success(LocatedParse(value: value, range: range), next)
            }
        }
    }
}
