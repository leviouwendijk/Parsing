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

    /// Commit to the sequence after the left parser succeeds.
    /// A failure in the right parser cannot trigger an alternative.
    @inlinable
    func thenCommitted<B: Sendable>(
        _ other: any Parser<B>
    ) -> AnyParser<(Output, B)> {
        let left = AnyParser(self)
        let right = AnyParser(other)

        return AnyParser<(Output, B)> { cursor in
            switch left.parse(cursor) {
            case .failure(let diagnostic):
                return .failure(diagnostic)
            case .success(let first, let next):
                switch right.parse(next) {
                case .success(let second, let final):
                    return .success((first, second), final)
                case .failure(let diagnostic):
                    return .failure(Diagnostic(
                        diagnostic.message,
                        severity: diagnostic.severity,
                        range: diagnostic.range,
                        committed: true
                    ))
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
