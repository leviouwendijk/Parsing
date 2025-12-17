import Foundation
// Open recursion (mirror of JSONValue flexibility)

/// `recursiveNode` lets a caller provide a `child()` parser to enable recursion.
/// Where structure is unknown, emit `.unknown(range)` so domain code can bind later.
public func recursiveNode(
    child: @escaping @Sendable () -> AnyTokenParser<SyntaxNode>
) -> AnyTokenParser<SyntaxNode> {

    // Atoms
    let atom =
        TokenParsers.string().map(SyntaxNode.string)
            .orElse(TokenParsers.number().map(SyntaxNode.number))
            .orElse(TokenParsers.identifier().map(SyntaxNode.atom))

    // Map: { key = child ... }
    let kv = TokenParsers.identifier()
        .skip(Expect(.equals))
        .then(AnyTokenParser<SyntaxNode> { c in child().parse(c) })

    let mapBody =
        kv.then(AnyTokenParser(Expect(.semicolon)).optional().map { (_: Token?) in () })
          .many(min: 0)
          .map { (pairs: [((String, SyntaxNode), Void?)]) -> SyntaxNode in
              let dict: [String: SyntaxNode] = Dictionary(
                  uniqueKeysWithValues: pairs.map { ($0.0.0, $0.0.1) }
              )
              return .map(dict)
          }

    let listBody =
        AnyTokenParser<SyntaxNode> { c in child().parse(c) }
            .then(AnyTokenParser(Expect(.comma)).optional().map { (_: Token?) in () })
            .many(min: 0)
            .map { pairs in SyntaxNode.list(pairs.map { $0.0 }) }

    let mapped =
        atom
        .orElse(TokenParsers.braces(mapBody))
        .orElse(TokenParsers.brackets(listBody))

    return mapped.orElse(AnyTokenParser<SyntaxNode> { c in
        var cur = c
        let start = cur.mark()
        while let t = cur.peek(),
              !t.sameCase(as: .newline),
              !t.sameCase(as: .right_brace),
              !t.sameCase(as: .right_bracket) {
            cur.advance()
        }
        let range = SourceRange(start, cur.index)
        return .success(.unknown(range), cur)
    })
}
