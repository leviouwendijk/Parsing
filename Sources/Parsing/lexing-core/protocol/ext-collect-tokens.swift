import Foundation

public extension Lexing {
    mutating func collectAllTokens() -> [Token] {
        var tokens: [Token] = []

        while true {
            let token = nextToken()
            tokens.append(token)

            if token == .eof {
                return tokens
            }
        }
    }

    @available(
        *,
        deprecated,
        message: "Use lexedTokens() on PositionedLexing. LexedToken keeps Token and PositionRange together."
    )
    mutating func collectAllTokensWithLineMap() -> ([Token], [Int]) {
        var tokens: [Token] = []
        var lines: [Int] = []

        index = 0
        line = 1
        column = 1

        while true {
            let tokenLine = line
            let token = nextToken()
            tokens.append(token)
            lines.append(tokenLine)

            if token == .eof {
                return (tokens, lines)
            }
        }
    }
}
