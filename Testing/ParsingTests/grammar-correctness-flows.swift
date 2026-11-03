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

            Test("ordered optional fields distinguish absence from invalid values") {
                let grammar = try Grammar(
                    nodes: [GrammarNode(
                        name: "ordered",
                        delimiter: .none,
                        order: .ordered,
                        fields: [
                            GrammarField("prefix", .val("string"), multiplicity: .optional(defaultValue: .string("P"))),
                            GrammarField("start", .val("string")),
                            GrammarField("note", .val("string"), multiplicity: .optional(defaultValue: .string("N"))),
                            GrammarField("alias", .val("string"), multiplicity: .optional()),
                            GrammarField("end", .val("string")),
                            GrammarField("suffix", .val("string"), multiplicity: .optional(defaultValue: .string("S")))
                        ]
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
                        sets: LexingSets(keywords: ["prefix", "start", "note", "alias", "end", "suffix"]),
                        options: options
                    )
                    let cursor = TokenCursor(lexedTokens: lexer.lexedTokens(), source: source)
                    return GrammarCompiler.compile(grammar, node: "ordered").parse(cursor)
                }

                let valid: [(String, [String: String])] = [
                    (
                        "start \"a\" end \"z\"",
                        ["prefix": "P", "start": "a", "note": "N", "end": "z", "suffix": "S"]
                    ),
                    (
                        "prefix \"p\" start \"a\" note = \"b\" alias \"c\" end \"z\" suffix \"s\"",
                        ["prefix": "p", "start": "a", "note": "b", "alias": "c", "end": "z", "suffix": "s"]
                    ),
                    (
                        "start \"a\" alias \"c\" end \"z\"",
                        ["prefix": "P", "start": "a", "note": "N", "alias": "c", "end": "z", "suffix": "S"]
                    )
                ]

                for (source, expected) in valid {
                    switch parse(source) {
                    case .failure(let diagnostic):
                        try Expect.equal(true, false, "valid ordered fields: \(diagnostic)")
                    case .success(let result, let next):
                        try Expect.equal(next.isEOF, true, "ordered fields consume input")
                        if case .object(let name, let fields) = result {
                            try Expect.equal(name, "ordered", "node identity")
                            try Expect.equal(fields.count, expected.count, "absent fields without defaults are omitted")
                            for (key, wanted) in expected {
                                if let nodes = fields[key], nodes.count == 1,
                                   case .string(let actual) = nodes[0] {
                                    try Expect.equal(actual, wanted, "field \(key)")
                                } else {
                                    try Expect.equal(true, false, "missing or incorrectly typed field \(key)")
                                }
                            }
                        } else {
                            try Expect.equal(true, false, "expected ordered object")
                        }
                    }
                }

                for source in [
                    "start \"a\" note 123 end \"z\"",
                    "start \"a\" note end \"z\"",
                    "start \"a\""
                ] {
                    switch parse(source) {
                    case .success:
                        try Expect.equal(true, false, "malformed or missing required value must fail: \(source)")
                    case .failure:
                        break
                    }
                }
            }

            Test("unordered grammar enforces field cardinality") {
                let grammar = try Grammar(
                    nodes: [GrammarNode(
                        name: "record",
                        delimiter: .braces,
                        order: .unordered,
                        fields: [
                            GrammarField("first", .val("string")),
                            GrammarField("second", .val("string")),
                            GrammarField("note", .val("string"), multiplicity: .optional(defaultValue: .string("default"))),
                            GrammarField("tag", .val("string"), multiplicity: .many(sep: .comma))
                        ]
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
                        sets: LexingSets(keywords: ["first", "second", "note", "tag"]),
                        options: options
                    )
                    let cursor = TokenCursor(lexedTokens: lexer.lexedTokens(), source: source)
                    return GrammarCompiler.compile(grammar, node: "record").parse(cursor)
                }

                switch parse(#"{ tag "one"; second "B"; tag "two","three"; first "A" }"#) {
                case .failure(let diagnostic):
                    try Expect.equal(true, false, "valid unordered record: \(diagnostic)")
                case .success(let result, let next):
                    try Expect.equal(next.isEOF, true, "all fields consumed")
                    if case .object("record", let fields) = result,
                       case .string("A")? = fields["first"]?.first,
                       case .string("B")? = fields["second"]?.first,
                       case .string("default")? = fields["note"]?.first {
                        let tags = fields["tag"] ?? []
                        try Expect.equal(tags.count, 3, "many fields retain all entries")
                        if tags.count == 3,
                           case .string("one") = tags[0],
                           case .string("two") = tags[1],
                           case .string("three") = tags[2] {
                            try Expect.equal(tags.count, 3, "repeated field order preserved")
                        } else {
                            try Expect.equal(true, false, "unexpected repeated values")
                        }
                    } else {
                        try Expect.equal(true, false, "unexpected required or default fields")
                    }
                }

                switch parse(#"{ first "A"; note "custom"; second "B" }"#) {
                case .failure(let diagnostic):
                    try Expect.equal(true, false, "present optional field: \(diagnostic)")
                case .success(let result, let next):
                    if case .object("record", let fields) = result,
                       case .string("custom")? = fields["note"]?.first {
                        try Expect.equal(next.isEOF, true, "present optional overrides default")
                    } else {
                        try Expect.equal(true, false, "optional value must override default")
                    }
                }

                let invalid = [
                    (#"{ second "B" }"#, "Missing required field 'first'"),
                    (#"{ first "A" }"#, "Missing required field 'second'"),
                    (#"{ first "A"; second "B"; first "C" }"#, "Duplicate field 'first'"),
                    (#"{ first "A"; second "B"; note "X"; note "Y" }"#, "Duplicate field 'note'")
                ]

                for (source, expected) in invalid {
                    switch parse(source) {
                    case .success:
                        try Expect.equal(true, false, "invalid cardinality accepted: \(source)")
                    case .failure(let diagnostic):
                        try Expect.equal(diagnostic.message, expected, "field cardinality diagnostic")
                        try Expect.equal(diagnostic.committed, true, "cardinality failure commits")
                    }
                }
            }

            Test("empty unordered grammars accept zero-field bodies") {
                let valid: [(GrammarNode.Delim, String)] = [
                    (.none, ""),
                    (.braces, "{}"),
                    (.brackets, "[]"),
                    (.parens, "()")
                ]

                func parse(_ source: String, delimiter: GrammarNode.Delim) throws -> TokenParseResult<GrammarResult> {
                    let grammar = try Grammar(
                        nodes: [GrammarNode(
                            name: "empty",
                            delimiter: delimiter,
                            order: .unordered,
                            fields: []
                        )],
                        values: .basic(),
                        child: { AnyTokenParser<SyntaxNode> { _ in .failure(Diagnostic("unused")) } }
                    )
                    var options = LexerOptions()
                    options.emit_whitespace = false
                    options.emit_newlines = false
                    var lexer = Lexer(
                        source: source,
                        sets: LexingSets(keywords: []),
                        options: options
                    )
                    let cursor = TokenCursor(lexedTokens: lexer.lexedTokens(), source: source)
                    return GrammarCompiler.compile(grammar, node: "empty").parse(cursor)
                }

                for (delimiter, source) in valid {
                    switch try parse(source, delimiter: delimiter) {
                    case .failure(let diagnostic):
                        try Expect.equal(true, false, "empty grammar must succeed: \(diagnostic)")
                    case .success(let result, let next):
                        if case .object(let name, let fields) = result {
                            try Expect.equal(name, "empty", "empty node identity")
                            try Expect.equal(fields.isEmpty, true, "no fields synthesized")
                        } else {
                            try Expect.equal(true, false, "expected empty object")
                        }
                        try Expect.equal(next.isEOF, true, "empty body consumed")
                    }
                }

                for (delimiter, source) in [
                    (GrammarNode.Delim.braces, "{ unexpected }"),
                    (.brackets, "[unexpected]"),
                    (.parens, "(unexpected)")
                ] {
                    switch try parse(source, delimiter: delimiter) {
                    case .success:
                        try Expect.equal(true, false, "nonempty body must not be accepted")
                    case .failure:
                        break
                    }
                }

                switch try parse("unexpected", delimiter: .none) {
                case .failure(let diagnostic):
                    try Expect.equal(true, false, "unwrapped empty grammar should be an identity: \(diagnostic)")
                case .success(let result, let next):
                    if case .object(let name, let fields) = result {
                        try Expect.equal(name, "empty", "unwrapped node identity")
                        try Expect.equal(fields.isEmpty, true, "unwrapped object has no fields")
                    } else {
                        try Expect.equal(true, false, "expected unwrapped empty object")
                    }
                    try Expect.equal(next.index, 0, "unwrapped empty grammar consumes nothing")
                    try Expect.equal(next.isEOF, false, "subsequent input remains available")
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
