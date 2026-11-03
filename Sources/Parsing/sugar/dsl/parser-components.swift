import Foundation

public struct ParserComponents: Sendable {
    public typealias Maker = @Sendable () -> AnyTokenParser<SyntaxNode>
    private var makers: [String: Maker] = [:]

    public init() {}

    public mutating func register(_ name: String, _ maker: @escaping Maker) {
        makers[name] = maker
    }

    public func make(_ name: String) -> AnyTokenParser<SyntaxNode>? {
        makers[name]?()
    }
}

// Common, domain-agnostic starter pack
public extension ParserComponents {
    static func basic() -> ParserComponents {
        var pc = ParserComponents()

        pc.register("ident") { TokenParsers.identifier().map(SyntaxNode.atom) }
        pc.register("string") { TokenParsers.string().map(SyntaxNode.string) }
        pc.register("number") { TokenParsers.number().map(SyntaxNode.number) }
        pc.register("dotPath") { TokenParsers.dotPath().map(SyntaxNode.string) }
        pc.register("arrowPath") { arrowPath().map(SyntaxNode.string) }

        // Small conveniences
        pc.register("int") {
            TokenParsers.number().flatMap { dec in
                AnyTokenParser<Int> { c in
                    // Accept integer-valued decimals (no fractional part).
                    let n = NSDecimalNumber(decimal: dec)
                    if dec == Decimal(n.intValue) { return .success(n.intValue, c) }
                    return .failure(Diagnostic("expected integer number"))
                }
            }
            .map { SyntaxNode.number(Decimal($0)) }
        }

        pc.register("bool") {
            // Accept keyword tokens or bare identifiers.
            let kwTrue = TokenParsers.keyword(.raw("true")).map { true }
            let kwFalse = TokenParsers.keyword(.raw("false")).map { false }
            let kwBool = kwTrue.orElse(kwFalse)

            let idBool = TokenParsers.identifier().flatMap { value in
                AnyTokenParser<Bool> { cursor in
                    switch value.lowercased() {
                    case "true": .success(true, cursor)
                    case "false": .success(false, cursor)
                    default: .failure(Diagnostic("expected boolean literal (true|false)"))
                    }
                }
            }
            return kwBool.orElse(idBool).map(SyntaxNode.boolean)
        }

        // "decimalLoose": accept number or quoted string convertible to Decimal
        pc.register("decimalLoose") {
            TokenParsers.number().orElse(
                TokenParsers.string().flatMap { source in
                    AnyTokenParser<Decimal> { cursor in
                        if let number = Decimal(string: source.replacingOccurrences(of: ",", with: ".")) {
                            return .success(number, cursor)
                        }
                        return .failure(Diagnostic("expected decimal-like string"))
                    }
                }
            )
            .map(SyntaxNode.number)
        }

        return pc
    }
}
