public extension StructuredParser.Compiled {
    func match(
        _ source: String
    ) -> StructuredParser.Match? {
        Evaluator.exactMatch(
            specification,
            in: source
        )
    }

    func firstMatch(
        in source: String
    ) -> StructuredParser.Match? {
        Evaluator.firstMatch(
            specification,
            in: source
        )
    }

    func matches(
        in source: String
    ) -> [StructuredParser.Match] {
        Evaluator.matches(
            specification,
            in: source
        )
    }

    func matches(
        in source: String,
        requiring cardinality: StructuredParser.Cardinality
    ) throws -> [StructuredParser.Match] {
        let matches = matches(
            in: source
        )

        try cardinality.validate(
            matches.count
        )

        return matches
    }
}

private enum Evaluator {
    private struct State {
        var cursor: Cursor
        var captures: [StructuredParser.Capture]
    }

    static func exactMatch(
        _ specification: StructuredParser.Specification,
        in source: String
    ) -> StructuredParser.Match? {
        let cursor = Cursor(source)

        guard
            let result = match(
                specification,
                from: cursor
            ),
            result.state.cursor.isEOF
        else {
            return nil
        }

        return result.match
    }

    static func firstMatch(
        _ specification: StructuredParser.Specification,
        in source: String
    ) -> StructuredParser.Match? {
        var scanner = Cursor(source)

        while true {
            let start = scanner.index

            if
                let result = match(
                    specification,
                    from: scanner
                ),
                result.state.cursor.index != start
            {
                return result.match
            }

            guard !scanner.isEOF else {
                return nil
            }

            scanner.advance()
        }
    }

    static func matches(
        _ specification: StructuredParser.Specification,
        in source: String
    ) -> [StructuredParser.Match] {
        var scanner = Cursor(source)
        var matches: [StructuredParser.Match] = []

        while true {
            let start = scanner.index

            if
                let result = match(
                    specification,
                    from: scanner
                ),
                result.state.cursor.index != start
            {
                matches.append(
                    result.match
                )
                scanner = result.state.cursor
                continue
            }

            guard !scanner.isEOF else {
                break
            }

            scanner.advance()
        }

        return matches
    }

    private static func match(
        _ specification: StructuredParser.Specification,
        from cursor: Cursor
    ) -> (
        match: StructuredParser.Match,
        state: State
    )? {
        let start = cursor.mark()

        guard let result = evaluate(
            specification,
            from: State(
                cursor: cursor,
                captures: []
            )
        ) else {
            return nil
        }

        return (
            StructuredParser.Match(
                range: result.cursor.range(
                    from: start
                ),
                captures: result.captures
            ),
            result
        )
    }

    private static func consumeLiteral(
        _ literal: String,
        from state: State
    ) -> State? {
        var next = state

        for expected in literal {
            guard next.cursor.peek() == expected else {
                return nil
            }

            next.cursor.advance()
        }

        return next
    }

    private static func evaluate(
        _ specification: StructuredParser.Specification,
        from state: State
    ) -> State? {
        switch specification {
        case .literal(let literal):
            return consumeLiteral(
                literal,
                from: state
            )

        case .identifier:
            var next = state

            guard
                let first = next.cursor.peek(),
                first.isLetter || first == "_"
            else {
                return nil
            }

            next.cursor.advance()

            while
                let character = next.cursor.peek(),
                character.isLetter
                    || character.isNumber
                    || character == "_"
            {
                next.cursor.advance()
            }

            return next

        case .sequence(let children):
            var next = state

            for child in children {
                guard let matched = evaluate(
                    child,
                    from: next
                ) else {
                    return nil
                }

                next = matched
            }

            return next

        case .choice(let alternatives):
            for alternative in alternatives {
                if let matched = evaluate(
                    alternative,
                    from: state
                ) {
                    return matched
                }
            }

            return nil

        case .optional(let child):
            return evaluate(
                child,
                from: state
            ) ?? state

        case .repetition(
            let child,
            let minimum,
            let maximum
        ):
            var next = state
            var count = 0

            while maximum.map({ count < $0 }) ?? true {
                guard let matched = evaluate(
                    child,
                    from: next
                ) else {
                    break
                }

                guard matched.cursor.index != next.cursor.index else {
                    break
                }

                next = matched
                count += 1
            }

            guard count >= minimum else {
                return nil
            }

            return next

        case .capture(let name, let child):
            let start = state.cursor.mark()

            guard var matched = evaluate(
                child,
                from: state
            ) else {
                return nil
            }

            let range = matched.cursor.range(
                from: start
            )
            let value = String(
                matched.cursor.input[
                    start..<matched.cursor.index
                ]
            )

            matched.captures.append(
                StructuredParser.Capture(
                    name: name,
                    value: value,
                    range: range
                )
            )

            return matched

        case .balanced(let opening, let closing):
            guard var next = consumeLiteral(
                opening,
                from: state
            ) else {
                return nil
            }

            var depth = 1

            while depth > 0 {
                if let closed = consumeLiteral(
                    closing,
                    from: next
                ) {
                    next = closed
                    depth -= 1
                    continue
                }

                if let opened = consumeLiteral(
                    opening,
                    from: next
                ) {
                    next = opened
                    depth += 1
                    continue
                }

                guard !next.cursor.isEOF else {
                    return nil
                }

                next.cursor.advance()
            }

            return next

        case .reference:
            return nil

        case .until(let terminator):
            var next = state

            while true {
                if evaluate(
                    terminator,
                    from: next
                ) != nil {
                    return next
                }

                guard !next.cursor.isEOF else {
                    return nil
                }

                next.cursor.advance()
            }
        }
    }
}
