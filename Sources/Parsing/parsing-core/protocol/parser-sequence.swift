import Foundation

public extension Parser {
    @inlinable
    func then<B: Sendable>(
        _ other: any Parser<B>
    ) -> AnyParser<(Output, B)> {
        let left = AnyParser(self)
        let right = AnyParser(other)

        return AnyParser<(Output, B)> { cursor in
            switch left.parse(cursor) {
            case .failure(let diagnostic):
                return .failure(diagnostic)

            case .success(let leftOutput, let next):
                switch right.parse(next) {
                case .failure(let diagnostic):
                    return .failure(diagnostic)

                case .success(let rightOutput, let final):
                    return .success(
                        (
                            leftOutput,
                            rightOutput
                        ),
                        final
                    )
                }
            }
        }
    }

    @inlinable
    func skip<B: Sendable>(
        _ other: any Parser<B>
    ) -> AnyParser<Output> {
        then(other).map { $0.0 }
    }

    @inlinable
    func keep<B: Sendable>(
        _ other: any Parser<B>
    ) -> AnyParser<B> {
        then(other).map { $0.1 }
    }
}
