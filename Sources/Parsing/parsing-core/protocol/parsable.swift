public protocol Parsable: Sendable {
    static func parser() throws -> AnyTokenParser<Self>
}

public extension Parsable {
    static func parse(_ cursor: TokenCursor) throws -> TokenParseResult<Self> {
        try parser().parse(cursor)
    }
}

public protocol SyntaxParsable: Parsable {
    static var syntax: AnyTokenParser<Self> { get }
}

public extension SyntaxParsable {
    static func parser() throws -> AnyTokenParser<Self> {
        syntax
    }
}
