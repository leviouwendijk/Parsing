import Foundation
import Position
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
          .flatMap { pairs -> AnyTokenParser<SyntaxNode> in
              var values: [String: SyntaxNode] = [:]
              for (entry, _) in pairs {
                  let (key, value) = entry
                  guard values.updateValue(value, forKey: key) == nil else {
                      return AnyTokenParser { _ in
                          .failure(Diagnostic("Duplicate map key '\(key)'", committed: true))
                      }
                  }
              }
              let node = SyntaxNode.map(values)
              return AnyTokenParser { .success(node, $0) }
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
              !t.samecase(as: .newline),
              !t.samecase(as: .right_brace),
              !t.samecase(as: .right_bracket) {
            cur.advance()
        }
        guard let range = cur.sourceRange(from: start) else {
            return .failure(Diagnostic(
                "Source provenance unavailable for unknown syntax node",
                committed: true
            ))
        }
        return .success(.unknown(range), cur)
    })
}
