import Foundation

public protocol DynamicallyParsable: Sendable {
    /// Provide the value parser table used by your grammar (you already have .basic()).
    static func parserComponents() -> ParserComponents
    /// Provide the node spec that represents this model in the DSL.
    static func grammarNode() -> GrammarNode
    /// Optional: customize lexing (keywords, string-block policies, …) per DSL.
    static func makeCursor(for source: String) -> TokenCursor

    /// Map folded SyntaxNode (produced by DynamicallyCompiler + fold) into the concrete model.
    static func fromSyntax(_ node: SyntaxNode) throws -> Self
}

public extension DynamicallyParsable {
    static func parser() -> AnyTokenParser<Self> {
        let grammar = Grammar(
            nodes: [grammarNode()],
            values: parserComponents(),
            child: { AnyTokenParser { _ in .failure(Diagnostic("no child")) } }
        )
        let p = GrammarCompiler.compile(grammar, node: grammarNode().name) // → AnyTokenParser<GResult>
        return p.map { fold($0) }                                           // → SyntaxNode
        .flatMap { syn in
            AnyTokenParser<Self> { c in
                do { return .success(try fromSyntax(syn), c) }
                catch { return .failure(Diagnostic("model decode failed: \(error)")) }
            }
        }
    }
}
