import Foundation

public extension Lexer {
    mutating func skipWhitespaceAndComments() {
        while let s = peek() {
            // whitespace
            if CharacterSet.whitespacesAndNewlines.contains(s) {
                advance(); continue
            }
            // line comments: //
            if s == "/", peek(aheadBy: 1) == "/" {
                // consume to end of line
                while let t = peek(), t != "\n" { advance() }
                continue
            }
            break
        }
    }
}
