import Foundation

public protocol DynamicallyParsable: Parsable {
    /// Provide the value parser table used by your grammar (you already have .basic()).
    static func parserComponents() -> ParserComponents
    /// Provide the node spec that represents this model in the DSL.
    static func grammarNode() -> GrammarNode
    /// Map the folded GrammarCompiler result into the concrete model.
    static func fromSyntax(_ node: SyntaxNode) throws -> Self
}

public extension DynamicallyParsable {
    static func parser() throws -> AnyTokenParser<Self> {
        let node = grammarNode()
        let grammar = try Grammar(nodes: [node], values: parserComponents())
        let p = GrammarCompiler.compile(grammar, node: node.name) // → AnyTokenParser<GResult>
        return p.map { fold($0) }                                           // → SyntaxNode
        .flatMap { syn in
            AnyTokenParser<Self> { c in
                do { return .success(try fromSyntax(syn), c) }
                catch { return .failure(Diagnostic("model decode failed: \(error)")) }
            }
        }
    }
}
