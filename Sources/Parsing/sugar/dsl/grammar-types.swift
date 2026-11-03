import Foundation

public extension Grammar {
    indirect enum Value: Sendable {
    case val(_ name: String)                     // use registered parser by name (e.g., "decimal")
    case node(_ ref: String)                     // reference to another GrammarNode (nesting/recursion)
    case list(_ elem: GrammarValue, sep: GrammarSeparator = .commaOrNewline)
    case map(_ value: GrammarValue, sep: GrammarSeparator = .semicolonOrNewline)
    case oneOf([GrammarValue])                         // alternatives
    case raw(_ p: AnyTokenParser<SyntaxNode>)    // escape hatch

    // Field absence is represented by Grammar.Multiplicity.optional,
    // not by an alternative that succeeds without consuming input.
}

    enum Separator: Sendable { case comma, semicolon, newline, commaOrNewline, semicolonOrNewline, none }

// Field multiplicity captures optional/many in one place.
    enum Multiplicity: Sendable {
    case one
    case optional(defaultValue: SyntaxNode? = nil)
    case many(sep: GrammarSeparator = .commaOrNewline)
}

    struct Field: Sendable {
    public let name: String
    public let value: GrammarValue
    public let multiplicity: GMultiplicity

    // Back-compat initializers
    public init(_ name: String, _ value: GrammarValue, required: Bool = true, repeated: Bool = false) {
        self.name = name
        self.value = value
        if repeated { self.multiplicity = .many() }
        else { self.multiplicity = required ? .one : .optional(defaultValue: nil) }
    }

    public init(_ name: String, _ value: GrammarValue, multiplicity: GMultiplicity) {
        self.name = name; self.value = value; self.multiplicity = multiplicity
    }
}

    enum Order: Sendable { case ordered, unordered }

    struct Node: Sendable {
    public let name: String
    public let opener: Keyword?          // optional leading keyword, e.g. `entry { ... }`
    public let delimiter: Delim          // (), [], {} around body
    public let order: GrammarOrder
    public let fields: [GrammarField]
    public let validate: (@Sendable ([String: [SyntaxNode]]) -> [Diagnostic])?

    public enum Delim: Sendable { case parens, braces, brackets, none }

    public init(
        name: String,
        opener: Keyword? = nil,
        delimiter: Delim = .braces,
        order: GrammarOrder = .unordered,
        fields: [GrammarField],
        validate: (@Sendable ([String: [SyntaxNode]]) -> [Diagnostic])? = nil
    ) {
        self.name = name; self.opener = opener; self.delimiter = delimiter; self.order = order
        self.fields = fields; self.validate = validate
    }
}

    struct Validators {
    public static func requireKeys(_ keys: Set<String>) -> (@Sendable ([String: [SyntaxNode]]) -> [Diagnostic]) {
        return { bucket in
            let missing = keys.subtracting(bucket.keys)
            return missing.isEmpty ? [] : [Diagnostic("missing keys: \(missing.joined(separator: ", "))")]
        }
    }
}

    enum Error: Swift.Error, Equatable, Sendable {
    case duplicate_node(String)
    case reserved_field(node: String, field: String)
}

}

public struct Grammar: Sendable {
    public let nodes: [String: GrammarNode]
    public let values: ParserComponents

    public init(nodes: [GrammarNode], values: ParserComponents) throws {
        var indexed: [String: GrammarNode] = [:]
        for node in nodes {
            guard !node.fields.contains(where: { $0.name == "_type" }) else {
                throw GrammarError.reserved_field(node: node.name, field: "_type")
            }
            guard indexed.updateValue(node, forKey: node.name) == nil else {
                throw GrammarError.duplicate_node(node.name)
            }
        }
        self.nodes = indexed
        self.values = values
    }
}
