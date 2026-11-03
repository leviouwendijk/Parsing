import Foundation
import Parsing
import Testing

extension ParsingTestSuite {
    static var grammarCorrectnessSuite: TestSuite {
        TestSuite("grammar-correctness", tags: ["grammar", "correctness"]) {
            Test("duplicate node declarations throw rather than trap") {
                let nodes = [
                    GrammarNode(name: "duplicate", fields: []),
                    GrammarNode(name: "duplicate", fields: [])
                ]
                do {
                    _ = try Grammar(
                        nodes: nodes,
                        values: .basic(),
                        child: { AnyTokenParser<SyntaxNode> { _ in .failure(Diagnostic("unused")) } }
                    )
                    try Expect.equal(true, false, "duplicate grammar must fail")
                } catch let error as GrammarError {
                    try Expect.equal(error, .duplicate_node("duplicate"), "typed duplicate error")
                }
            }

            Test("empty parser chains are valid identities") {
                let parser: AnyTokenParser<[String]> = chain([])
                let cursor = TokenCursor(lexedTokens: [], source: "")
                switch parser.parse(cursor) {
                case .success(let values, let next):
                    try Expect.equal(values.isEmpty, true, "empty sequence")
                    try Expect.equal(next.index, cursor.index, "no consumption")
                case .failure:
                    try Expect.equal(true, false, "empty chain should not fail")
                }
            }

            Test("Boolean grammar values remain typed") {
                let grammar = try Grammar(
                    nodes: [GrammarNode(
                        name: "settings",
                        delimiter: .none,
                        order: .ordered,
                        fields: [GrammarField("enabled", .val("bool"))]
                    )],
                    values: .basic(),
                    child: { AnyTokenParser<SyntaxNode> { _ in .failure(Diagnostic("unused")) } }
                )

                for (source, expected) in [("enabled true", true), ("enabled false", false)] {
                    var options = LexerOptions()
                    options.emit_whitespace = false
                    var lexer = Lexer(
                        source: source,
                        sets: LexingSets(keywords: ["enabled", "true", "false"]),
                        options: options
                    )
                    let cursor = TokenCursor(lexedTokens: lexer.lexedTokens(), source: source)
                    switch GrammarCompiler.compile(grammar, node: "settings").parse(cursor) {
                    case .failure(let diagnostic):
                        try Expect.equal(true, false, "unexpected Boolean failure: \(diagnostic)")
                    case .success(let result, let next):
                        if case .object(let name, let fields) = result,
                           name == "settings",
                           let values = fields["enabled"],
                           values.count == 1,
                           case .boolean(let actual) = values[0] {
                            try Expect.equal(actual, expected, "typed Boolean value")
                            try Expect.equal(next.isEOF, true, "entire input consumed")
                        } else {
                            try Expect.equal(true, false, "expected a Boolean syntax node")
                        }
                    }
                }
            }

            Test("empty alternatives fail with a diagnostic instead of crashing") {
                let grammar = try Grammar(
                    nodes: [GrammarNode(
                        name: "root",
                        delimiter: .none,
                        order: .ordered,
                        fields: [GrammarField("x", .oneOf([]))]
                    )],
                    values: .basic(),
                    child: { AnyTokenParser<SyntaxNode> { _ in .failure(Diagnostic("unused")) } }
                )
                var lexer = Lexer(source: "x", sets: LexingSets(keywords: ["x"]))
                let cursor = TokenCursor(lexedTokens: lexer.lexedTokens(), source: "x")
                switch GrammarCompiler.compile(grammar, node: "root").parse(cursor) {
                case .failure: break
                case .success: try Expect.equal(true, false, "empty choice must fail")
                }
            }

            Test("separated lists enforce separators and support a trailing separator") {
                func parse(_ source: String, sep: GrammarSeparator = .comma, min: Int = 0) -> TokenParseResult<[String]> {
                    var options = LexerOptions()
                    options.emit_whitespace = false
                    options.emit_newlines = false
                    var lexer = Lexer(source: source, sets: LexingSets(keywords: []), options: options)
                    let cursor = TokenCursor(lexedTokens: lexer.lexedTokens(), source: source)
                    return separatedList(item: AnyTokenParser(PIdent()), sep: sep, min: min).parse(cursor)
                }

                switch parse("alpha,beta,") {
                case .failure(let diagnostic):
                    try Expect.equal(true, false, "valid separated list: \(diagnostic)")
                case .success(let values, let next):
                    try Expect.equal(values, ["alpha", "beta"], "both items captured")
                    try Expect.equal(next.isEOF, true, "trailing comma consumed")
                }

                switch parse("alpha beta") {
                case .failure(let diagnostic):
                    try Expect.equal(true, false, "first item should remain valid: \(diagnostic)")
                case .success(let values, let next):
                    try Expect.equal(values, ["alpha"], "adjacent item not silently accepted")
                    try Expect.equal(next.isEOF, false, "unseparated input remains unconsumed")
                }

                switch parse("alpha beta", sep: .none, min: 2) {
                case .failure(let diagnostic):
                    try Expect.equal(true, false, "separator-free list should work: \(diagnostic)")
                case .success(let values, let next):
                    try Expect.equal(values, ["alpha", "beta"], "none means adjacency is allowed")
                    try Expect.equal(next.isEOF, true, "all adjacent items consumed")
                }

                switch parse("") {
                case .failure:
                    try Expect.equal(true, false, "zero minimum accepts empty list")
                case .success(let values, let next):
                    try Expect.equal(values.isEmpty && next.isEOF, true, "empty list identity")
                }
                if case .success = parse("", min: 1) {
                    try Expect.equal(true, false, "positive minimum rejects empty list")
                }
            }

            Test("named and anonymous maps share separator and duplicate-key semantics") {
                let grammar = try Grammar(
                    nodes: [GrammarNode(
                        name: "settings",
                        opener: .raw("settings"),
                        delimiter: .braces,
                        order: .ordered,
                        fields: [GrammarField("values", .map(.val("string"), sep: .semicolon))]
                    )],
                    values: .basic(),
                    child: { AnyTokenParser<SyntaxNode> { _ in .failure(Diagnostic("unused")) } }
                )

                func parse(_ source: String) -> TokenParseResult<GrammarResult> {
                    var options = LexerOptions()
                    options.emit_whitespace = false
                    options.emit_newlines = false
                    var lexer = Lexer(
                        source: source,
                        sets: LexingSets(keywords: ["settings", "values"]),
                        options: options
                    )
                    let cursor = TokenCursor(lexedTokens: lexer.lexedTokens(), source: source)
                    return GrammarCompiler.compile(grammar, node: "settings").parse(cursor)
                }

                let valid = [
                    #"settings { values = { alpha = "a"; beta = "b"; } }"#,
                    #"settings { alpha = "a"; beta = "b"; }"#
                ]
                for source in valid {
                    switch parse(source) {
                    case .failure(let diagnostic):
                        try Expect.equal(true, false, "valid named or anonymous map: \(diagnostic)")
                    case .success(let result, let next):
                        try Expect.equal(next.isEOF, true, "entire map consumed")
                        if case .object(let name, let fields) = result,
                           name == "settings",
                           case .map(let entries)? = fields["values"]?.first,
                           case .string("a")? = entries["alpha"],
                           case .string("b")? = entries["beta"] {
                            try Expect.equal(entries.count, 2, "map entries preserved")
                        } else {
                            try Expect.equal(true, false, "map values must remain typed")
                        }
                    }
                }

                for source in [
                    #"settings { values = { alpha = "a" beta = "b" } }"#,
                    #"settings { alpha = "a" beta = "b" }"#
                ] {
                    switch parse(source) {
                    case .failure:
                        break
                    case .success(_, let next):
                        try Expect.equal(next.isEOF, false, "unseparated pair must not be accepted")
                    }
                }

                for source in [
                    #"settings { values = { alpha = "a"; alpha = "b" } }"#,
                    #"settings { alpha = "a"; alpha = "b" }"#
                ] {
                    switch parse(source) {
                    case .success:
                        try Expect.equal(true, false, "duplicate key must fail")
                    case .failure(let diagnostic):
                        try Expect.equal(diagnostic.committed, true, "duplicate is committed")
                        try Expect.equal(diagnostic.message, "Duplicate map key 'alpha'", "duplicate diagnostic retained")
                    }
                }
            }

            Test("duplicate anonymous map keys fail without trapping") {
                let grammar = try Grammar(
                    nodes: [GrammarNode(
                        name: "pairs",
                        opener: .raw("pairs"),
                        delimiter: .braces,
                        fields: [GrammarField("kv", .map(.val("string")))]
                    )],
                    values: .basic(),
                    child: { AnyTokenParser<SyntaxNode> { _ in .failure(Diagnostic("unused")) } }
                )
                let source = #"pairs { a = "x"; a = "y" }"#
                var lexer = Lexer(source: source, sets: LexingSets(keywords: ["pairs", "kv"]))
                let cursor = TokenCursor(lexedTokens: lexer.lexedTokens(), source: source)
                switch GrammarCompiler.compile(grammar, node: "pairs").parse(cursor) {
                case .failure: break
                case .success: try Expect.equal(true, false, "duplicate map key must fail")
                }
            }
        }
    }
}
