import Foundation

public func softIdentifier(reserving reserved: Set<String>) -> AnyTokenParser<String> {
    TokenParsers.identifier().flatMap { name -> AnyTokenParser<String> in
        if reserved.contains(name) {
            return AnyTokenParser { _ in .failure(Diagnostic("identifier may not be a reserved keyword: '\(name)'")) }
        } else {
            return AnyTokenParser { c in .success(name, c) }
        }
    }
}
