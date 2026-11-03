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
        withSkipped(cursor) { start in
            switch prefix.parse(start) {
            case .failure(let diagnostic):
                return .failure(diagnostic)
            case .success(let parsedPrefix, let afterPrefix):
                return withSkipped(afterPrefix) { beforeDelimited in
                    let wrappedContent = AnyTokenParser<Content> { input in
                        withSkipped(input) { beforeContent in
                            switch content.parse(beforeContent) {
                            case .failure(let diagnostic):
                                return .failure(diagnostic)
                            case .success(let parsedContent, let afterContent):
                                return withSkipped(afterContent) { final in
                                    .success(parsedContent, final)
                                }
                            }
                        }
                    }

                    switch delimiter.wrap(wrappedContent).parse(beforeDelimited) {
                    case .failure(let diagnostic):
                        return .failure(diagnostic)
                    case .success(let parsedContent, let next):
                        return withSkipped(next) { final in
                            .success(
                                .init(prefix: parsedPrefix, content: parsedContent),
                                final
                            )
                        }
                    }
                }
            }
        }
    }

    private func withSkipped<T: Sendable>(
        _ cursor: TokenCursor,
        _ parse: (TokenCursor) -> TokenParseResult<T>
    ) -> TokenParseResult<T> {
        switch consumeSkip(from: cursor) {
        case .failure(let diagnostic):
            return .failure(diagnostic)
        case .success(_, let next):
            return parse(next)
        }
    }

    private func consumeSkip(from cursor: TokenCursor) -> TokenParseResult<Void> {
        var current = cursor

        while true {
            switch skip.parse(current) {
            case .success(_, let next):
                guard next.index >= current.index, next.index <= current.tokens.count else {
                    return .failure(Diagnostic(
                        "skip parser moved outside the remaining input",
                        range: current.currentRange,
                        committed: true
                    ))
                }
                if next.index == current.index {
                    return .success((), current)
                }
                current = next
            case .failure(let diagnostic):
                return diagnostic.committed
                    ? .failure(diagnostic)
                    : .success((), current)
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
