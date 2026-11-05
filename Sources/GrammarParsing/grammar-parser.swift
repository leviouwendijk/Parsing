import Foundation
import enum Grammar.Grammar
import Lexing
import Parsing
import Position

/// Native, ordered-choice compiler for the supported non-left-recursive Grammar IR.
/// The older Parsing.Grammar DSL remains unchanged in its own module.
public struct GrammarParser: Sendable {
    public struct Node: Sendable {
        public let name: String
        public let field: String?
        public let text: String?
        public let children: [Node]
        public let range: Range<Position.Offset<Position.Unit.UTF8>>

        public init(
            name: String,
            field: String? = nil,
            text: String? = nil,
            children: [Node] = [],
            range: Range<Position.Offset<Position.Unit.UTF8>>
        ) {
            self.name = name
            self.field = field
            self.text = text
            self.children = children
            self.range = range
        }

        func withField(_ name: String) -> Self {
            Self(name: self.name, field: name, text: text,
                 children: children, range: range)
        }
    }

    public enum Failure: Swift.Error, Sendable {
        case unsupported_left_recursion(String)
        case unsupported_precedence
        case lexical(LexicalDiagnostic)
        case syntax(Diagnostic)
    }

    public let language: Grammar.Language
    private let lexer: GrammarLexer
    private let inlinePatterns: [String: NSRegularExpression]

    public init(language: Grammar.Language) throws {
        let analysis = try language.analyze()
        if let name = analysis.left_recursive.sorted().first {
            throw Failure.unsupported_left_recursion(name)
        }
        if language.productions.contains(where: { Self.hasPrecedence($0.expression) }) {
            throw Failure.unsupported_precedence
        }
        var patterns: [String: NSRegularExpression] = [:]
        for production in language.productions {
            try Self.collectPatterns(production.expression, into: &patterns)
        }
        self.language = language
        self.lexer = try GrammarLexer(language: language)
        self.inlinePatterns = patterns
    }

    /// A standard Parsing.TokenParser, consuming the grammar's canonical LexingResult.
    public func parser() -> AnyTokenParser<Node> {
        production(language.start)
    }

    public func parse(_ source: String, filePath: String? = nil) throws -> Node {
        let lexed = try lexer.lex(source)
        if let error = lexed.diagnostics.first {
            throw Failure.lexical(error)
        }
        let cursor = TokenCursor(lexing: lexed, selection: .significant, filePath: filePath)
        switch parser().parse(cursor) {
        case .failure(let diagnostic):
            throw Failure.syntax(diagnostic)
        case .success(let node, let next):
            guard next.isEOF else {
                throw Failure.syntax(Diagnostic(
                    "Unexpected trailing grammar tokens",
                    range: next.currentRange,
                    utf8Range: next.currentUTF8Range
                ))
            }
            return node
        }
    }

    private func production(_ name: String) -> AnyTokenParser<Node> {
        AnyTokenParser { cursor in
            guard let definition = language.production(named: name) else {
                return .failure(Diagnostic("Undefined production '\(name)'", committed: true))
            }
            switch expression(definition.expression).parse(cursor) {
            case .failure(let diagnostic):
                return .failure(diagnostic)
            case .success(let children, let next):
                guard let range = next.utf8Range(from: cursor.index) else {
                    return .failure(Diagnostic(
                        "Missing UTF-8 range for production '\(name)'",
                        utf8Range: cursor.currentUTF8Range,
                        committed: true
                    ))
                }
                return .success(Node(name: name, children: children, range: range), next)
            }
        }
    }

    private func expression(_ value: Grammar.Expression) -> AnyTokenParser<[Node]> {
        switch value {
        case .blank:
            return AnyTokenParser { .success([], $0) }
        case .literal(let text):
            return terminal(expected: "literal '\(text)'", accepts: { _, raw in raw == text })
        case .pattern(let pattern):
            guard let regex = inlinePatterns[pattern] else {
                return AnyTokenParser { cursor in
                    .failure(Diagnostic("Uncompiled pattern '\(pattern)'",
                                        utf8Range: cursor.currentUTF8Range, committed: true))
                }
            }
            return terminal(expected: "pattern '\(pattern)'", accepts: { _, raw in
                let range = NSRange(location: 0, length: (raw as NSString).length)
                guard let result = regex.firstMatch(in: raw, options: [.anchored], range: range) else {
                    return false
                }
                return result.range == range
            })
        case .symbol(.terminal(let name)):
            return terminal(expected: "terminal '\(name)'", accepts: { found, _ in found == name })
        case .symbol(.production(let name)):
            return production(name).map { [$0] }
        case .sequence(let children):
            let parts = children.map(expression)
            return AnyTokenParser { cursor in
                var current = cursor
                var all: [Node] = []
                for part in parts {
                    switch part.parse(current) {
                    case .failure(let diagnostic):
                        return .failure(diagnostic)
                    case .success(let nodes, let next):
                        all.append(contentsOf: nodes)
                        current = next
                    }
                }
                return .success(all, current)
            }
        case .choice(let children):
            let alternatives = children.map(expression)
            return AnyTokenParser { cursor in
                var best: Diagnostic?
                for alternative in alternatives {
                    switch alternative.parse(cursor) {
                    case .success(let nodes, let next):
                        return .success(nodes, next)
                    case .failure(let diagnostic):
                        if diagnostic.committed { return .failure(diagnostic) }
                        let candidate = diagnostic.utf8Range?.lowerBound.offset ?? -1
                        let previous = best?.utf8Range?.lowerBound.offset ?? -1
                        if best == nil || candidate > previous { best = diagnostic }
                    }
                }
                return .failure(best ?? Diagnostic(
                    "No grammar alternative matched",
                    range: cursor.currentRange,
                    utf8Range: cursor.currentUTF8Range
                ))
            }
        case .optional(let child):
            return expression(child).optional().map { $0 ?? [] }
        case .repeat0(let child):
            return repeated(expression(child), min: 0)
        case .repeat1(let child):
            return repeated(expression(child), min: 1)
        case .field(let name, let child):
            return expression(child).map { $0.map { $0.withField(name) } }
        case .precedence:
            return AnyTokenParser { cursor in
                .failure(Diagnostic("Native precedence is not compiled",
                                    utf8Range: cursor.currentUTF8Range, committed: true))
            }
        }
    }

    private func repeated(
        _ part: AnyTokenParser<[Node]>,
        min: Int
    ) -> AnyTokenParser<[Node]> {
        AnyTokenParser { cursor in
            var current = cursor
            var nodes: [Node] = []
            var count = 0
            while true {
                switch part.parse(current) {
                case .success(let matched, let next):
                    guard next.index > current.index else {
                        return .failure(Diagnostic(
                            "Repeated grammar expression consumed no input",
                            range: current.currentRange,
                            utf8Range: current.currentUTF8Range,
                            committed: true
                        ))
                    }
                    nodes.append(contentsOf: matched)
                    count += 1
                    current = next
                case .failure(let diagnostic):
                    let failedAt = diagnostic.utf8Range?.lowerBound.offset ?? -1
                    let startedAt = current.currentUTF8Range?.lowerBound.offset ?? -1
                    // A failed candidate that consumed part of a production
                    // must not be mistaken for the end of a repetition.
                    if diagnostic.committed || failedAt > startedAt {
                        return .failure(diagnostic)
                    }
                    return count >= min ? .success(nodes, current) : .failure(diagnostic)
                }
            }
        }
    }

    private func terminal(
        expected: String,
        accepts: @Sendable @escaping (String, String) -> Bool
    ) -> AnyTokenParser<[Node]> {
        AnyTokenParser { cursor in
            guard case .grammar_terminal(let name, let raw)? = cursor.peek(),
                  accepts(name, raw) else {
                return .failure(Diagnostic(
                    "Expected \(expected)",
                    range: cursor.currentRange,
                    utf8Range: cursor.currentUTF8Range
                ))
            }
            var next = cursor
            next.advance()
            guard let range = next.utf8Range(from: cursor.index) else {
                return .failure(Diagnostic(
                    "Missing UTF-8 terminal range",
                    utf8Range: cursor.currentUTF8Range,
                    committed: true
                ))
            }
            return .success([Node(name: name, text: raw, range: range)], next)
        }
    }

    private static func hasPrecedence(_ value: Grammar.Expression) -> Bool {
        switch value {
        case .precedence: true
        case .sequence(let children), .choice(let children):
            children.contains(where: hasPrecedence)
        case .optional(let child), .repeat0(let child), .repeat1(let child), .field(_, let child):
            hasPrecedence(child)
        default: false
        }
    }

    private static func collectPatterns(
        _ value: Grammar.Expression,
        into result: inout [String: NSRegularExpression]
    ) throws {
        switch value {
        case .pattern(let source):
            guard result[source] == nil else { return }
            result[source] = try NSRegularExpression(pattern: source)
        case .sequence(let children), .choice(let children):
            for child in children { try collectPatterns(child, into: &result) }
        case .optional(let child), .repeat0(let child), .repeat1(let child),
             .field(_, let child), .precedence(_, _, let child):
            try collectPatterns(child, into: &result)
        default:
            break
        }
    }
}
