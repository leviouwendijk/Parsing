import Foundation

public struct TakeWhile: Parser, Sendable {
    public typealias Output = String

    public let minimumCount: Int
    public let expectation: String

    private let predicate: @Sendable (Character) -> Bool

    public init(
        where predicate: @Sendable @escaping (Character) -> Bool,
        minimumCount: Int = 0,
        expectation: String = "matching input"
    ) {
        self.predicate = predicate
        self.minimumCount = max(
            0,
            minimumCount
        )
        self.expectation = expectation
    }

    public func parse(
        _ cursor: Cursor
    ) -> ParseResult<String> {
        var cursor = cursor
        let start = cursor.mark()
        var count = 0

        while let character = cursor.peek(),
              predicate(character) {
            cursor.advance()
            count += 1
        }

        guard count >= minimumCount else {
            return .failure(
                Diagnostic(
                    "expected \(expectation)",
                    range: .point(cursor.offset)
                )
            )
        }

        return .success(
            cursor.slice(
                from: start
            ),
            cursor
        )
    }
}

public struct Remainder: Parser, Sendable {
    public typealias Output = String

    public init() {}

    public func parse(
        _ cursor: Cursor
    ) -> ParseResult<String> {
        var cursor = cursor
        let start = cursor.mark()

        cursor.advance {
            _ in true
        }

        return .success(
            cursor.slice(
                from: start
            ),
            cursor
        )
    }
}

public struct EndOfInput: Parser, Sendable {
    public typealias Output = Void

    public init() {}

    public func parse(
        _ cursor: Cursor
    ) -> ParseResult<Void> {
        guard cursor.isEOF else {
            return .failure(
                Diagnostic(
                    "expected end of input",
                    range: .point(cursor.offset)
                )
            )
        }

        return .success(
            (),
            cursor
        )
    }
}
