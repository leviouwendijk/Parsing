public func dotPath() -> AnyTokenParser<String> { TokenParsers.dotPath() }

// "a->b->c"  ->  "a.b.c"
public func arrowPath() -> AnyTokenParser<String> {
    let seg = TokenParsers.identifier()
    let tail = AnyTokenParser(Expect(.arrow)) // tokenized as '->'
        .keep(seg).many(min: 0)
    return seg.then(tail).map { head, rest in ([head] + rest).joined(separator: ".") }
}

// "a.b#foo"   keep variant part separate if desired
public func aliasedPathWithVariant() -> AnyTokenParser<(path: String, variant: String?)> {
    dotPath().then(AnyTokenParser(Expect(.hash)).keep(TokenParsers.identifier()).optional())
        .map { ($0, $1) }
}
