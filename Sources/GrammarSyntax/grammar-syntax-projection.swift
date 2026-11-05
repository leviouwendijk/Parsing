import enum Grammar.Grammar
import GrammarParsing
import Lexing
import Syntax

/// Adapter boundary: grammar and parser own recognition; Syntax owns presentation.
public struct GrammarSyntaxProjection: Sendable {
    public let tree: GrammarParser.Node
    public let document: SyntaxDocument

    public init(language: Grammar.Language, source: String) throws {
        let compiler = try GrammarParser(language: language)
        let tree = try compiler.parse(source)
        let lexed = try GrammarLexer(language: language).lex(source)
        let vocabulary = try Self.vocabulary(for: language)
        var captures: [SyntaxCapture] = []

        for lexeme in lexed.tokens {
            let name: String
            switch lexeme.token {
            case .grammar_terminal(let terminal, _):
                name = terminal
            case .grammar_extra:
                name = "@extra"
            default:
                continue
            }
            captures.append(try SyntaxCapture(
                kind: SyntaxIdentifier(language: language.name, name: name),
                segments: [SyntaxSourceRange(lexeme.range)],
                layer: .lexical
            ))
        }

        func appendNodes(_ node: GrammarParser.Node) throws {
            let span = try SyntaxSourceRange(node.range)
            if node.text == nil {
                captures.append(try SyntaxCapture(
                    kind: SyntaxIdentifier(language: language.name, name: node.name),
                    segments: [span],
                    layer: .syntactic
                ))
            }
            if let field = node.field {
                captures.append(try SyntaxCapture(
                    kind: SyntaxIdentifier(language: language.name, name: "@field:\(field)"),
                    segments: [span],
                    layer: .syntactic
                ))
            }
            for child in node.children {
                try appendNodes(child)
            }
        }

        try appendNodes(tree)
        self.tree = tree
        self.document = try SyntaxDocument(
            source: source, vocabularies: [vocabulary], captures: captures
        )
    }

    public static func vocabulary(for language: Grammar.Language) throws -> SyntaxVocabulary {
        var definitions: [SyntaxDefinitionRecord] = []
        for production in language.productions {
            definitions.append(try .init(
                name: production.name, roles: roles(for: production.role)
            ))
        }
        for terminal in language.terminals {
            definitions.append(try .init(
                name: terminal.name, roles: roles(for: terminal.role)
            ))
        }

        var inline: [String: [SyntaxRole]] = [:]
        for production in language.productions {
            collectNames(production.expression, into: &inline)
        }
        for name in inline.keys.sorted() {
            definitions.append(try .init(name: name, roles: inline[name] ?? []))
        }
        if !language.extras.isEmpty {
            definitions.append(try .init(name: "@extra", roles: [.text]))
        }
        return try SyntaxVocabulary(id: language.name, definitions: definitions)
    }

    private static func roles(for name: String?) -> [SyntaxRole] {
        guard let name else { return [] }
        let role: SyntaxRole
        switch name {
        case "keyword": role = .keyword
        case "identifier", "variable": role = .identifier
        case "declaration": role = .declaration
        case "property": role = .property
        case "type": role = .type
        case "function": role = .function
        case "namespace": role = .namespace
        case "reference": role = .reference
        case "number": role = .number
        case "string": role = .string
        case "comment": role = .comment
        case "operator": role = .operator
        case "punctuation": role = .punctuation
        case "text": role = .text
        case "invalid": role = .invalid
        default: role = .custom(name)
        }
        return [role]
    }

    private static func collectNames(
        _ expression: Grammar.Expression,
        into names: inout [String: [SyntaxRole]]
    ) {
        switch expression {
        case .literal(let value):
            names["@literal:\(value)"] = [.punctuation]
        case .pattern(let value):
            names["@pattern:\(value)"] = [.text]
        case .field(let name, let child):
            names["@field:\(name)"] = [.custom("field")]
            collectNames(child, into: &names)
        case .sequence(let children), .choice(let children):
            for child in children { collectNames(child, into: &names) }
        case .optional(let child), .repeat0(let child), .repeat1(let child),
             .precedence(_, _, let child):
            collectNames(child, into: &names)
        default:
            break
        }
    }
}
