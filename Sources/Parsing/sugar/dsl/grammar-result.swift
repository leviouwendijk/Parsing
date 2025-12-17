import Foundation

public enum GrammarResult: Sendable {
    case object(name: String, fields: [String: [SyntaxNode]])
    case list([SyntaxNode])
    case map([String: SyntaxNode])
    case atom(SyntaxNode)
}

public enum GrammarCompiler {
    public static func compile(_ grammar: Grammar, node name: String) -> AnyTokenParser<GrammarResult> {
        AnyTokenParser { ctx in
            guard let spec = grammar.nodes[name] else {
                return .failure(Diagnostic("Unknown node: \(name)"))
            }
            return buildNodeParser(grammar, spec).parse(ctx)
        }
    }

    // Turn a GrammarValue into AnyTokenParser<SyntaxNode>
    private static func compileValue(_ g: Grammar, _ v: GrammarValue) -> AnyTokenParser<SyntaxNode> {
        switch v {
        case .val(let nm):
            // if let p: AnyTokenParser<String>  = g.values.make(nm) { return p.map(SyntaxNode.string) }grammar
            if let p: AnyTokenParser<String>  = g.values.make(nm) {
                // Identifiers should stay atoms, not strings.
                if nm == "ident" { return p.map(SyntaxNode.atom) }
                return p.map(SyntaxNode.string)
            }
            if let p: AnyTokenParser<Decimal> = g.values.make(nm) { return p.map(SyntaxNode.number) }
            if let p: AnyTokenParser<Int>     = g.values.make(nm) { return p.map { .number(Decimal($0)) } }
            if let p: AnyTokenParser<SyntaxNode> = g.values.make(nm) { return p }
            return AnyTokenParser { _ in .failure(Diagnostic("No value parser named \(nm)")) }

        case .node(let ref):
            return compile(g, node: ref).map { fold($0) }

        case .list(let elem, let sep):
            let item = compileValue(g, elem)
            return separatedList(item: item, sep: sep).map(SyntaxNode.list)

        case .map(let val, let sep, _ /* allowUnknown */):
            let key  = TokenParsers.identifier()
            let pair = key
                .skip(Expect(.equals))
                .then(compileValue(g, val))            // (String, SyntaxNode)
                .map { (k, v) in (k, v) }

            return delimited(
                .braces,
                body: pair
                    // .then(separator(sep).optional())    // ((String,SyntaxNode), Void?)
                    .then(separator(sep).many(min: 0))
                    .many(min: 0)
                    .map { $0.map { $0.0 } }            // [(String, SyntaxNode)]
            )
            .map { pairs -> SyntaxNode in
                let dict: [String: SyntaxNode] = Dictionary(
                    uniqueKeysWithValues: pairs.map { ($0.0, $0.1) })
                return .map(dict)
            }

        case .oneOf(let arr):
            precondition(!arr.isEmpty, "oneOf requires at least one alternative")
            return arr.dropFirst().reduce(compileValue(g, arr[0])) { acc, nxt in
                acc.orElse(compileValue(g, nxt))
            }

        case .raw(let p):
            return p
        }
    }

    private static func buildNodeParser(_ g: Grammar, _ n: GrammarNode) -> AnyTokenParser<GrammarResult> {
        // Optional opener keyword
        let withOpener: AnyTokenParser<Void> =
            (n.opener != nil) ? TokenParsers.keyword(n.opener!).map { () }
                              : AnyTokenParser { .success((), $0) }

        // // Build a parser for a single declared field
        // func fieldShape(_ f: GrammarField) -> AnyTokenParser<(String, [SyntaxNode])> {
        //     let key = TokenParsers.keyword(.raw(f.name)).map { () }
        //     let val = compileValue(g, f.value)

        //     switch f.multiplicity {
        //     case .one:
        //         return key.then(val).map { (_, v) in (f.name, [v]) }

        //     // case .optional(let def):
        //     //     let present = key.then(val).map { (_, v) in (f.name, [v]) }
        //     //     if let def = def {
        //     //         return present.orElse(AnyTokenParser { .success((f.name, [def]), $0) })
        //     //     } else {
        //     //         return present.optional().map { opt in
        //     //             opt ?? (f.name, [])   // absent => empty list (collected later)
        //     //         }
        //     //     }

        //     case .optional:
        //         // Important: do NOT succeed if the key isn’t present.
        //         // If the keyword doesn’t match, this parser must FAIL so the unordered choice can try others.
        //         // Defaults (if any) are injected AFTER collection (see patch #2 below).
        //         return key.then(val).map { (_, v) in (f.name, [v]) }

        //     case .many(let sep):
        //         let list = separatedList(item: val, sep: sep)
        //         return key.then(list).map { (_, xs) in (f.name, xs) }
        //     }
        // }

         func fieldShape(_ f: GrammarField) -> AnyTokenParser<(String, [SyntaxNode])> {
             let key = TokenParsers.keyword(.raw(f.name)).map { () }
            let val = compileValue(g, f.value)
            // Support both "key value" and "key = value"
            let maybeEq = AnyTokenParser(Expect(.equals)).optional().map { (_: Token?) in () }
 
             switch f.multiplicity {
             case .one:
                return key.then(maybeEq).then(val).map { _ , v in (f.name, [v]) }
 
            case .optional:
                // Do not succeed when the key is absent; but if present, accept optional '='
                return key.then(maybeEq).then(val).map { _ , v in (f.name, [v]) }
 
             case .many(let sep):
                let list = separatedList(item: val, sep: sep)
                return key.then(maybeEq).then(list).map { _ , xs in (f.name, xs) }
             }
         }

        // Collect fields
        let body: AnyTokenParser<[(String, [SyntaxNode])]>
        switch n.order {
        case .unordered:
            // // repeatedly parse any field; stop when no progress
            // let choices = n.fields.map { fieldShape($0) } // [(String, [SyntaxNode])]
            // let seed: AnyTokenParser<(String, [SyntaxNode])> =
            //     choices.first ?? AnyTokenParser { ctx in .success(("", []), ctx) }

            // let one = choices.dropFirst().reduce(seed) { $0.orElse($1) }

            // body = one
            //     .then(separator(.semicolonOrNewline).optional()) // ((String,[SyntaxNode]), Void?)
            //     .many(min: 0)
            //     .map { $0.map { $0.0 } }                          // [(String, [SyntaxNode])]

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

        // let delimitedBody = delimited(n.delimiter, body: body)

        // Special-case: single map field may use "anonymous body" (no leading field name).
        // Example: node "pairs" with one field "kv" of type .map(...):
        //     pairs { a = "x"; b = "y" }   // no "kv { ... }" wrapper
        let delimitedBody: AnyTokenParser<[(String,[SyntaxNode])]> = {
            // Build the normal, explicit-fields body first
            let explicit = body

            // If exactly one field and it is a .map, also accept a raw map payload in the node body.
            if n.fields.count == 1,
               case let .map(val, sep, _) = n.fields[0].value {
                // Build "a = <val>" pairs (no outer braces; node braces are already in effect)
                let pair = TokenParsers.identifier()
                    .skip(Expect(.equals))
                    .then(compileValue(g, val))          // (String, SyntaxNode)
                    .map { (k, v) in (k, v) }

                // let anonMap: AnyTokenParser<[(String,[SyntaxNode])]> =
                //     pair.then(separator(sep).optional())
                //         .many(min: 0)
                //         .map { pairs in
                //             let dict = Dictionary(uniqueKeysWithValues: pairs.map { $0.0 })
                //             // Wrap under the declared field name
                //             return [(n.fields[0].name, [ .map(dict) ])]
                //         }
                // Require at least one k=v pair to avoid empty success that prevents the closing '}' from matching.
                let anonMap: AnyTokenParser<[(String,[SyntaxNode])]> =
                    pair.then(separator(sep).optional())
                        .many(min: 1) // <- was 0
                        .map { pairs in
                            let dict = Dictionary(uniqueKeysWithValues: pairs.map { $0.0 })
                            // Wrap under the declared field name
                            return [(n.fields[0].name, [ .map(dict) ])]
                        }

                // // Try explicit fields first; if none match, accept anonymous map
                // return delimited(n.delimiter, body: explicit.orElse(anonMap))

                // Try explicit fields *only if it made progress*;
                // otherwise, fall back to anonymous body parsing.
                let explicitNonEmpty = requireProgress(explicit)
                return delimited(n.delimiter, body: explicitNonEmpty.orElse(anonMap))
            } else {
                return delimited(n.delimiter, body: explicit)
            }
        }()

        return withOpener.then(delimitedBody).flatMap { _, pairs in
            // // Merge into name → [nodes]
            // var bucket: [String: [SyntaxNode]] = [:]
            // for (k, vs) in pairs where !vs.isEmpty {
            //     bucket[k, default: []].append(contentsOf: vs)
            // }

            // // run optional validator
            // if let validate = n.validate {
            //     let diags = validate(bucket)
            //     if let d = diags.first {
            //         return AnyTokenParser<GrammarResult> { _ in .failure(d) }
            //     }
            // }

            // let frozen = bucket
            // return AnyTokenParser<GrammarResult> { ctx in
            //     .success(.object(name: n.name, fields: frozen), ctx)
            // }

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
