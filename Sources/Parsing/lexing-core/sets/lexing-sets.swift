import Foundation

public struct LexingSets: Sendable, Codable {
    public let keywords: Set<String>     // words to emit as .keyword
    public let idents: Set<String>       // optionally force some words as .ident
    public let stringBlockKeywords: Set<String> // words that trigger {…} blocks

    public init(keywords: Set<String>, idents: Set<String> = [], stringBlockKeywords: Set<String> = []) {
        self.keywords = keywords
        self.idents = idents
        self.stringBlockKeywords = stringBlockKeywords
    }
}

// Example: Concatenation flavor (for .conany / .configure / .conselect)
public enum LexingFlavor: Sendable { 
    public enum Concatenation: Sendable {
        case conany
        case conignore
        case configure
        case conselect

        public func set() -> Set<String> {
            switch self {
            case .conany:
                return Set(["", ""])

            case .conignore:
                return Set(["", ""])

            case .configure:
                return Set(["", ""])

            case .conselect:
                return Set(["", ""])

            }
        }
    }

    public enum Generic: Sendable {
        case any
    }
}
