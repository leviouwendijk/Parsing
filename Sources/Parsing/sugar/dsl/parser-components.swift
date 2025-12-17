import Foundation

// public struct ValueParsers {
public struct ParserComponents: @unchecked Sendable {
    public typealias Maker<T> = @Sendable () -> AnyTokenParser<T>
    private var makers: [String: Any] = [:]

    public init() {}

    public mutating func register<T>(_ name: String, _ mk: @escaping Maker<T>) {
        makers[name] = mk
    }

    public func make<T>(_ name: String) -> AnyTokenParser<T>? {
        (makers[name] as? Maker<T>)?()
    }
}

// Common, domain-agnostic starter pack
public extension ParserComponents {
    static func basic() -> ParserComponents {
        var pc = ParserComponents()

        pc.register("ident")     { TokenParsers.identifier() }                           // String
        pc.register("string")    { TokenParsers.string() }                               // String
        pc.register("number")    { TokenParsers.number() }                               // Decimal
        pc.register("dotPath")   { TokenParsers.dotPath() }                              // String
        pc.register("arrowPath") { arrowPath() }                                         // String  ("a->b" => "a.b")  

        // Small conveniences
        pc.register("int") {
            TokenParsers.number().flatMap { dec in
                AnyTokenParser<Int> { c in
                    // accept integer-valued decimals (no fractional part)
                    let n = NSDecimalNumber(decimal: dec)
                    if dec == Decimal(n.intValue) { return .success(n.intValue, c) }
                    return .failure(Diagnostic("expected integer number"))
                }
            }
        }

        pc.register("bool") {
            // bool from ident/keyword: true/false
            // TokenParsers.identifier().flatMap { s in
            //     AnyTokenParser<Bool> { c in
            //         switch s.lowercased() {
            //         case "true":  return .success(true, c)
            //         case "false": return .success(false, c)
            //         default:      return .failure(Diagnostic("expected boolean literal (true|false)"))
            //         }
            //     }
            // }
            
            // Prefer keyword tokens, fall back to bare identifiers.
            let kwTrue  = TokenParsers.keyword(.raw("true")).map { true  }
            let kwFalse = TokenParsers.keyword(.raw("false")).map { false }
            let kwBool  = kwTrue.orElse(kwFalse)

            let idBool  = TokenParsers.identifier().flatMap { s in
                AnyTokenParser<Bool> { c in
                    switch s.lowercased() {
                    case "true":  .success(true, c)
                    case "false": .success(false, c)
                    default:      .failure(Diagnostic("expected boolean literal (true|false)"))
                    }
                }
            }
            return kwBool.orElse(idBool)
        }

        // "decimalLoose": accept number or quoted string convertible to Decimal
        pc.register("decimalLoose") {
            TokenParsers.number().orElse(
                TokenParsers.string().flatMap { s in
                    AnyTokenParser<Decimal> { c in
                        if let d = Decimal(string: s.replacingOccurrences(of: ",", with: ".")) {
                            return .success(d, c)
                        }
                        return .failure(Diagnostic("expected decimal-like string"))
                    }
                }
            )
        }

        return pc
    }
}
