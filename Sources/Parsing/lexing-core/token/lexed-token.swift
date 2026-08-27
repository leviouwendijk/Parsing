import Position

public struct LexedToken: Sendable, Codable, Hashable {
    public let token: Token
    public let range: PositionRange

    public init(
        token: Token,
        range: PositionRange
    ) {
        self.token = token
        self.range = range
    }
}
