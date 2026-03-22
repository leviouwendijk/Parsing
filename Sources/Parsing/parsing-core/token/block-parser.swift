import Foundation

public struct BlockParseOutput<Prefix: Sendable, Content: Sendable>: Sendable {
    public let prefix: Prefix?
    public let content: Content

    public init(
        prefix: Prefix?,
        content: Content
    ) {
        self.prefix = prefix
        self.content = content
    }
}

public struct BlockParser<Prefix: Sendable, Content: Sendable>: TokenParser {
    public typealias Output = BlockParseOutput<Prefix, Content>

    public let prefix: AnyTokenParser<Prefix?>
    public let delimiter: TokenDelimiter
    public let content: AnyTokenParser<Content>

    public init(
        prefix: AnyTokenParser<Prefix?>,
        delimiter: TokenDelimiter = .braces,
        content: AnyTokenParser<Content>
    ) {
        self.prefix = prefix
        self.delimiter = delimiter
        self.content = content
    }

    public func parse(
        _ cursor: TokenCursor
    ) -> TokenParseResult<BlockParseOutput<Prefix, Content>> {
        switch prefix.parse(cursor) {
            case .failure(let diagnostic):
                return .failure(diagnostic)

            case .success(let parsedPrefix, let afterPrefix):
                let body = delimiter.wrap(content)

                switch body.parse(afterPrefix) {
                    case .failure(let diagnostic):
                        return .failure(diagnostic)

                    case .success(let parsedContent, let next):
                        return .success(
                            .init(
                                prefix: parsedPrefix,
                                content: parsedContent
                            ),
                            next
                        )
                }
        }
    }
}

public extension BlockParser {
    init(
        delimiter: TokenDelimiter = .braces,
        content: AnyTokenParser<Content>
    ) where Prefix == Never {
        self.init(
            prefix: AnyTokenParser<Never?> { c in
                .success(nil, c)
            },
            delimiter: delimiter,
            content: content
        )
    }
}
