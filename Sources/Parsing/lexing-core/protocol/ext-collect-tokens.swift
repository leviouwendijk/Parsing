import Foundation

public extension Lexing {
    mutating func collectAllTokens() -> [Token] {
        var toks: [Token] = []
        while true {
            let t = nextToken()
            toks.append(t)
            if t == .eof { break }
        }
        return toks
    }

    mutating func collectAllTokensWithLineMap() -> ([Token], [Int]) {
        var toks: [Token] = []; var lines: [Int] = []
        index = 0; line = 1; column = 1
        while true {
            let l0 = line
            let t = nextToken()
            toks.append(t); lines.append(l0)
            if t == .eof { break }
        }
        return (toks, lines)
    }
}
