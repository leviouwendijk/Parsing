import Foundation

public struct RecursiveTokenParser<Output: Sendable>: TokenParser {
    public final class Ref: @unchecked Sendable {
        fileprivate var parser: AnyTokenParser<Output>?

        public init() {}

        public func set<P: TokenParser>(
            _ parser: P
        ) where P.Output == Output {
            self.parser = AnyTokenParser(parser)
        }

        public func set(
            _ parser: AnyTokenParser<Output>
        ) {
            self.parser = parser
        }
    }

    private let ref: Ref

    public init(
        _ configure: (Ref) -> Void
    ) {
        let ref = Ref()
        configure(ref)
        self.ref = ref
    }

    public func parse(
        _ cursor: TokenCursor
    ) -> TokenParseResult<Output> {
        guard let parser = ref.parser else {
            return .failure(
                Diagnostic("recursive token parser not initialized")
            )
        }

        return parser.parse(cursor)
    }
}
