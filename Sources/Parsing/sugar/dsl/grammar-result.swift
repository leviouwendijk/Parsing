import Foundation

public extension Grammar {
    enum Result: Sendable {
        case object(name: String, fields: [String: [SyntaxNode]])
        case list([SyntaxNode])
        case map([String: SyntaxNode])
        case atom(SyntaxNode)
    }

    enum Compiler {
        public static func compile(_ grammar: Grammar, node name: String) -> AnyTokenParser<GrammarResult> {
            AnyTokenParser { cursor in
                guard let spec = grammar.nodes[name] else {
                    return .failure(Diagnostic("Unknown node: \(name)"))
                }
                return buildNodeParser(grammar, spec).parse(cursor)
            }
        }

    // Turn a GrammarValue into AnyTokenParser<SyntaxNode>
    private static func compileValue(_ g: Grammar, _ v: GrammarValue) -> AnyTokenParser<SyntaxNode> {
        switch v {
        case .val(let nm):
            if let p: AnyTokenParser<String>  = g.values.make(nm) {
                // Identifiers should stay atoms, not strings.
                if nm == "ident" { return p.map(SyntaxNode.atom) }
                return p.map(SyntaxNode.string)
            }
            if let p: AnyTokenParser<Decimal> = g.values.make(nm) { return p.map(SyntaxNode.number) }
            if let p: AnyTokenParser<Int>     = g.values.make(nm) { return p.map { .number(Decimal($0)) } }
            if let p: AnyTokenParser<Bool>    = g.values.make(nm) { return p.map(SyntaxNode.boolean) }
            if let p: AnyTokenParser<SyntaxNode> = g.values.make(nm) { return p }
            return AnyTokenParser { _ in .failure(Diagnostic("No value parser named \(nm)")) }

        case .node(let ref):
            return compile(g, node: ref).map { fold($0) }

        case .list(let elem, let sep):
            let item = compileValue(g, elem)
            return separatedList(item: item, sep: sep).map(SyntaxNode.list)

        case .map(let value, let sep, _):
            return delimited(.braces, body: mapPairs(g, value: value, sep: sep))

        case .oneOf(let arr):
            guard let first = arr.first else {
                return AnyTokenParser { _ in
                    .failure(Diagnostic("oneOf requires at least one alternative", committed: true))
                }
            }
            return arr.dropFirst().reduce(compileValue(g, first)) { acc, nxt in
                acc.orElse(compileValue(g, nxt))
            }

        case .raw(let p):
            return p
        }
    }

    private static func mapPairs(
        _ grammar: Grammar,
        value: GrammarValue,
        sep: GrammarSeparator,
        min: Int = 0
    ) -> AnyTokenParser<SyntaxNode> {
        let pair = TokenParsers.identifier()
            .skip(Expect(.equals))
            .then(compileValue(grammar, value))

        return separatedList(item: pair, sep: sep, min: min)
            .flatMap { pairs -> AnyTokenParser<SyntaxNode> in
                var values: [String: SyntaxNode] = [:]
                for (key, value) in pairs {
                    guard values.updateValue(value, forKey: key) == nil else {
                        return AnyTokenParser { _ in
                            .failure(Diagnostic("Duplicate map key '\(key)'", committed: true))
                        }
                    }
                }
                let node = SyntaxNode.map(values)
                return AnyTokenParser { .success(node, $0) }
            }
    }

    private static func buildNodeParser(_ g: Grammar, _ n: GrammarNode) -> AnyTokenParser<GrammarResult> {
        // Optional opener keyword
        let withOpener: AnyTokenParser<Void>
        if let opener = n.opener {
            withOpener = TokenParsers.keyword(opener).map { () }
        } else {
            withOpener = AnyTokenParser { .success((), $0) }
        }

        func fieldShape(_ field: GrammarField) -> AnyTokenParser<(String, [SyntaxNode])> {
            let key = TokenParsers.keyword(.raw(field.name)).map { () }
            let value = compileValue(g, field.value)
            // Accept both "key value" and "key = value".
            let maybeEquals = AnyTokenParser(Expect(.equals)).optional().map { (_: Token?) in () }

            switch field.multiplicity {
            case .one, .optional:
                return key.then(maybeEquals).then(value).map { _, parsed in
                    (field.name, [parsed])
                }
            case .many(let separator):
                let list = separatedList(item: value, sep: separator)
                return key.then(maybeEquals).then(list).map { _, parsed in
                    (field.name, parsed)
                }
            }
        }

        // Collect fields
        let body: AnyTokenParser<[(String, [SyntaxNode])]>
        switch n.order {
        case .unordered:
            // Repeatedly parse any field; allow BLANK LINES between fields.
            let choices = n.fields.map { fieldShape($0) } // [(String, [SyntaxNode])]
            let seed: AnyTokenParser<(String, [SyntaxNode])> =
                choices.first ?? AnyTokenParser { ctx in .success(("", []), ctx) }
            let one = choices.dropFirst().reduce(seed) { $0.orElse($1) }

            // Treat runs of '\n' as valid inter-field separators.
            let newline   = AnyTokenParser(Expect(.newline))
            let blankRun  = newline.many(min: 1).map { _ in () }
            let trailingSep = separator(.semicolonOrNewline)
                .orElse(blankRun)                    // ; | \n | \n\n...
                .many(min: 0)
                .map { _ in () }

            // Skip any leading blank lines before attempting the next field.
            let oneField = blankRun.many(min: 0)
                .then(one)
                .then(trailingSep)
                // tuple shape is: (([()], (String, [SyntaxNode])), ())
                // we want the inner (String, [SyntaxNode])
                .map { t in t.0.1 }

            // Prevent stalls (wrap with the free function, not a method call)
            let oneFieldNP = requireProgress(oneField)

            // Collect
            body = oneFieldNP.many(min: 0)

        case .ordered:
            let parts = n.fields.map { f -> AnyTokenParser<(String, [SyntaxNode])> in fieldShape(f) }
            body = chain(parts)
        }


        // Special-case: single map field may use "anonymous body" (no leading field name).
        // Example: node "pairs" with one field "kv" of type .map(...):
        //     pairs { a = "x"; b = "y" }   // no "kv { ... }" wrapper
        let delimitedBody: AnyTokenParser<[(String,[SyntaxNode])]> = {
            // Build the normal, explicit-fields body first
            let explicit = body

            // If exactly one field and it is a .map, also accept a raw map payload in the node body.
            if n.fields.count == 1,
               case let .map(val, sep, _) = n.fields[0].value {
                // A missing explicit field is a recoverable mismatch, not an invariant failure.
                let explicitNonEmpty = AnyTokenParser<[(String, [SyntaxNode])]> { cursor in
                    switch explicit.parse(cursor) {
                    case .success(let fields, let next) where next.index > cursor.index:
                        return .success(fields, next)
                    case .success:
                        return .failure(Diagnostic("expected explicit field", range: cursor.currentRange))
                    case .failure(let diagnostic):
                        return .failure(diagnostic)
                    }
                }

                // The node's own delimiter supplies braces; require a nonempty raw map.
                let anonMap = mapPairs(g, value: val, sep: sep, min: 1)
                    .map { node in [(n.fields[0].name, [node])] }

                return delimited(n.delimiter, body: explicitNonEmpty.orElse(anonMap))
            } else {
                return delimited(n.delimiter, body: explicit)
            }
        }()

        return withOpener.then(delimitedBody).flatMap { _, pairs in
            // Merge into name → [nodes]
            var bucket: [String: [SyntaxNode]] = [:]
            for (k, vs) in pairs where !vs.isEmpty {
                bucket[k, default: []].append(contentsOf: vs)
            }

            // Inject defaults for *optional* fields that were not present
            for f in n.fields {
                if case .optional(let def) = f.multiplicity, let def = def, bucket[f.name] == nil {
                    bucket[f.name] = [def]
                }
            }

            // run optional validator
            if let validate = n.validate {
                let diags = validate(bucket)
                if let d = diags.first { return AnyTokenParser { _ in .failure(d) } }
            }

            let frozen = bucket
            return AnyTokenParser<GrammarResult> { ctx in
                .success(.object(name: n.name, fields: frozen), ctx)
            }

        }
    }
    }
}
