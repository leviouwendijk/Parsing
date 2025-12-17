import Foundation

/// `for (entity) in (account)` head composer
public func forHead(
    entityPath: AnyTokenParser<String> = TokenParsers.dotPath(),
    accountPath: AnyTokenParser<String> = TokenParsers.dotPath()
) -> AnyTokenParser<(entity: String, account: String)> {
    TokenParsers.keyword(.raw("for"))
        .keep(TokenParsers.parens(entityPath))
        .skip(TokenParsers.keyword(.raw("in")))
        .then(TokenParsers.parens(accountPath))
        .map { (entity: $0, account: $1) }
}
