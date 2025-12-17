import Foundation

public enum CommentSignature: Sendable, Equatable {
    case line(prefix: String)                     // e.g. "//", "#"
    case block(start: String, end: String, allows_nesting: Bool = false) // e.g. "/*", "*/"
}

