public protocol PositionedLexing: Lexing {
    mutating func nextLexedToken() -> LexedToken
}

public extension PositionedLexing {
    mutating func lexedTokens() -> [LexedToken] {
        var result: [LexedToken] = []

        while true {
            let lexed = nextLexedToken()
            result.append(lexed)

            if lexed.token == .eof {
                return result
            }
        }
    }
}
