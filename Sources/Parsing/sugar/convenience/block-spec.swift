import Foundation

// Tiny helpers for common shapes
public struct BlockSpec<Head: Sendable, Body: Sendable> {
    public let opener: Keyword
    public let parseHead: AnyTokenParser<Head>
    public let parseBody: AnyTokenParser<Body>
    
    public init(
        opener: Keyword,
        parseHead: AnyTokenParser<Head>,
        parseBody: AnyTokenParser<Body>
    ) {
        self.opener = opener
        self.parseHead = parseHead
        self.parseBody = parseBody
    }
}

/// `keyword opener { parseHead; parseBody }`
public func block<Head: Sendable, Body: Sendable>(
    _ spec: BlockSpec<Head, Body>
) -> AnyTokenParser<(head: Head, body: Body)> {
    TokenParsers.keyword(spec.opener)
        .keep( TokenParsers.braces( spec.parseHead.then(spec.parseBody) ) )
        .map { (h, b) in (head: h, body: b) }
}
