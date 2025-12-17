public func stringBlock(_ name: String) -> AnyTokenParser<String> {
    TokenParsers.keyword(.raw(name))
        .keep(TokenParsers.braces(TokenParsers.string()))
}
