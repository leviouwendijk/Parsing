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
    public let skip: AnyTokenParser<Void>

    public init(
        prefix: AnyTokenParser<Prefix?>,
        delimiter: TokenDelimiter = .braces,
        content: AnyTokenParser<Content>,
        skip: AnyTokenParser<Void> = AnyTokenParser<Void> { cursor in
            .success((), cursor)
        }
    ) {
        self.prefix = prefix
        self.delimiter = delimiter
        self.content = content
        self.skip = skip
    }

    public func parse(
        _ cursor: TokenCursor
    ) -> TokenParseResult<BlockParseOutput<Prefix, Content>> {
        let start = consumeSkip(from: cursor)

        switch prefix.parse(start) {
            case .failure(let diagnostic):
                return .failure(diagnostic)

            case .success(let parsedPrefix, let afterPrefix):
                let beforeDelimited = consumeSkip(from: afterPrefix)

                let wrappedContent = AnyTokenParser<Content> { cursor in
                    let beforeContent = consumeSkip(from: cursor)

                    switch content.parse(beforeContent) {
                        case .failure(let diagnostic):
                            return .failure(diagnostic)

                        case .success(let parsedContent, let afterContent):
                            let final = consumeSkip(from: afterContent)
                            return .success(parsedContent, final)
                    }
                }

                let body = delimiter.wrap(wrappedContent)

                switch body.parse(beforeDelimited) {
                    case .failure(let diagnostic):
                        return .failure(diagnostic)

                    case .success(let parsedContent, let next):
                        let final = consumeSkip(from: next)

                        return .success(
                            .init(
                                prefix: parsedPrefix,
                                content: parsedContent
                            ),
                            final
                        )
                }
        }
    }

    private func consumeSkip(
        from cursor: TokenCursor
    ) -> TokenCursor {
        var cur = cursor

        while true {
            switch skip.parse(cur) {
                case .success(_, let next):
                    if next.index == cur.index {
                        return cur
                    }
                    cur = next

                case .failure:
                    return cur
            }
        }
    }
}

public extension BlockParser {
    init(
        delimiter: TokenDelimiter = .braces,
        content: AnyTokenParser<Content>,
        skip: AnyTokenParser<Void> = AnyTokenParser<Void> { cursor in
            .success((), cursor)
        }
    ) where Prefix == Never {
        self.init(
            prefix: AnyTokenParser<Never?> { c in
                .success(nil, c)
            },
            delimiter: delimiter,
            content: content,
            skip: skip
        )
    }
}
