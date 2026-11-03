import Foundation

/// Generic `key = value` list inside braces: `{ k = v ... }`.
/// Callers decide the value parser and allowed keys.
public func keyValuePairs<Value: Sendable>(
    allowedKeys: Set<String>,
    value: AnyTokenParser<Value>,
    pairSeparator: AnyTokenParser<Void> = (
        AnyTokenParser(Expect(.semicolon)).map { (_: Token) in () }
            .orElse(AnyTokenParser(Expect(.newline)).map { (_: Token) in () })
            .optional()
            .map { _ in () }
    )
) -> AnyTokenParser<[String: Value]> {
    let key = TokenParsers.identifier()
        .withBacktracking()
        .flatMap { name -> AnyTokenParser<String> in
            if !allowedKeys.isEmpty && !allowedKeys.contains(name) {
                return AnyTokenParser<String> { c in .failure(Diagnostic("unknown key '\(name)'")) }
            }
            return AnyTokenParser<String> { c in .success(name, c) }
        }

    let pair =
        key
        .skip(Expect(.equals))
        .then(value)
        .map { (k, v) in (k, v) }

    return TokenParsers.braces(
        pair.then(pairSeparator.optional())
            .many(min: 0)
            .flatMap { pairs -> AnyTokenParser<[String: Value]> in
                var values: [String: Value] = [:]
                for (entry, _) in pairs {
                    let (key, value) = entry
                    guard values.updateValue(value, forKey: key) == nil else {
                        return AnyTokenParser { _ in
                            .failure(Diagnostic("Duplicate key '\(key)'", committed: true))
                        }
                    }
                }
                let frozen = values
                return AnyTokenParser { .success(frozen, $0) }
            }
    )
}
