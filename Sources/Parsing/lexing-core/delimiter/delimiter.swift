import Foundation

/// A balanced delimiter pair with optional nesting behavior.
public struct Delimiter: Sendable, Equatable {
    public let start: String
    public let end: String
    public let allowsNesting: Bool

    // Common presets
    public static let braces       = Delimiter(start: "{", end: "}", allowsNesting: true)
    public static let brackets     = Delimiter(start: "[", end: "]", allowsNesting: true)
    public static let parens       = Delimiter(start: "(", end: ")", allowsNesting: true)
    public static let angle        = Delimiter(start: "<", end: ">", allowsNesting: true)
    public static let doubleQuotes = Delimiter(start: "\"", end: "\"", allowsNesting: false)
    public static let singleQuotes = Delimiter(start: "\'", end: "\'", allowsNesting: false)

    public init(start: String, end: String, allowsNesting: Bool = false) {
        self.start = start; self.end = end; self.allowsNesting = allowsNesting
    }
}
