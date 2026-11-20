import Foundation
import enum Grammar.Grammar
import GrammarParsing
import GrammarSyntax
import Position
import Syntax
import SyntaxLSP
import Testing

@main
enum GrammarParsingTestCLI {
    static func main() async {
        let reporter = PlainTextTestReporter(
            verbose: CommandLine.arguments.contains("--verbose"),
            output: ClosureTestTextOutput { text in
                FileHandle.standardOutput.write(Data(text.utf8))
            }
        )
        let result = await TestRunner.run(suite, sink: reporter)
        Foundation.exit(result.isFailure ? 1 : 0)
    }

    static let suite = TestSuite("grammar-native-parsing") {
        Test("Grammar.Language drives lexing and native token combinators") {
            let compiled = try GrammarParser(language: language())
            let source = "let alpha = beta\r\nlet gamma = delta"
            let document = try compiled.parse(source)
            try Expect.equal(document.name, "file", "root production")
            try Expect.equal(document.children.count, 2, "two assignments")
            try Expect.equal(document.range.upperBound.offset, source.utf8.count,
                             "source-backed root range")
            let first = document.children[0]
            try Expect.equal(first.name, "assignment", "production node")
            try Expect.equal(first.children[1].field, "name", "declared field")
            try Expect.equal(first.children[1].text, "alpha", "matched source text")
            try Expect.equal(first.children[3].field, "value", "value field")
        }
        Test("structured bridge retains fields, repetitions and canonical hierarchy") {
            let compiled = try GrammarParser(language: language())
            let source = "let alpha = beta\nlet gamma = delta"
            let result = try compiled.parseStructured(source)
            try Expect.equal(result.root.children.count, 2, "original hierarchy retained")
            try Expect.equal(result.match.range.offsets, 0..<source.count, "exact source match")
            try Expect.equal(result.match.captures.map(\.name),
                             ["name", "value", "name", "value"], "repeated field ordering")
            try Expect.equal(result.match.captures.map(\.value),
                             ["alpha", "beta", "gamma", "delta"], "source-backed values")
        }
        Test("structured bridge rejects partial-grapheme legacy spans") {
            let lower = try Position.Offset<Position.Unit.UTF8>(0)
            let upper = try Position.Offset<Position.Unit.UTF8>(1)
            let partial = GrammarParser.Node(name: "token", field: "part", text: "e",
                                             range: lower..<upper)
            try Expect.throwsError("Character bridge never rounds a combining sequence") {
                _ = try partial.structuredMatch(in: "e\u{301}")
            }
        }
        Test("grammar roles and exact UTF-16 LSP spans derive from one language") {
            let grammar = try emojiLanguage()
            let source = "\u{1F415}alpha\r\n\u{1F415}beta"
            let output = try GrammarSyntaxProjection(language: grammar, source: source)
            try Expect.equal(output.tree.children.count, 2, "two parsed items")
            let lexical = output.document.captures.filter {
                $0.layer == .lexical && $0.kind.name != "@extra"
            }
            let fields = output.document.captures.filter {
                $0.layer == .syntactic && $0.kind.name == "@field:name"
            }
            try Expect.equal(lexical.count, 4, "four significant lexemes")
            try Expect.equal(fields.count, 2, "two field captures")
            let legend = try SyntaxLSP.Legend(types: ["keyword", "variable"])
            let tokens = try SyntaxLSP.project(document: output.document, legend: legend, rules: [
                .init(selector: .init(role: .keyword, layer: .lexical), type: "keyword"),
                .init(selector: .init(role: .identifier, layer: .lexical), type: "variable")
            ])
            try Expect.equal(SyntaxLSP.encode(tokens), [
                0, 0, 2, 0, 0,
                0, 2, 5, 1, 0,
                1, 0, 2, 0, 0,
                0, 2, 4, 1, 0
            ], "emoji UTF-16 units and CRLF split")
        }
        Test("Tree-sitter and native parsing agree on supported grammar fixtures") {
            try GrammarBackendParity.run(language())
        }
        Test("syntax failure includes exact UTF-8 source range") {
            let compiled = try GrammarParser(language: language())
            do {
                _ = try compiled.parse("let = value")
                try Expect.true(false, "expected failed identifier")
            } catch GrammarParser.Failure.syntax(let diagnostic) {
                try Expect.equal(diagnostic.utf8Range?.lowerBound.offset, 4,
                                 "failure at equals token")
            }
        }
        Test("repetition preserves partially matched production diagnostics") {
            let compiled = try GrammarParser(language: language())
            do {
                _ = try compiled.parse("let a = b\nlet = c")
                try Expect.true(false, "malformed second statement must fail")
            } catch GrammarParser.Failure.syntax(let diagnostic) {
                try Expect.equal(diagnostic.utf8Range?.lowerBound.offset, 14,
                                 "failure at second assignment equals")
            }
        }
        Test("unrecognized scalar is returned as lexical failure") {
            let compiled = try GrammarParser(language: language())
            do {
                _ = try compiled.parse("let x = 🐕")
                try Expect.true(false, "expected lexical error")
            } catch GrammarParser.Failure.lexical(let diagnostic) {
                try Expect.equal(diagnostic.range.lowerBound.offset, 8, "start")
                try Expect.equal(diagnostic.range.upperBound.offset, 12, "end")
            }
        }
        Test("left recursion is refused before parsing") {
            let grammar = try Grammar.Language(name: "recursive", start: "root", productions: [
                .init(name: "root", expression: .choice([
                    .symbol(.production("root")), .literal("x")
                ]))
            ])
            do {
                _ = try GrammarParser(language: grammar)
                try Expect.true(false, "left recursion cannot use ordered-choice compiler")
            } catch GrammarParser.Failure.unsupported_left_recursion("root") {}
        }
        Test("precedence is refused rather than silently ignored") {
            let grammar = try Grammar.Language(name: "precedence", start: "root", productions: [
                .init(name: "root", expression: .precedence(1, .left, .literal("x")))
            ])
            do {
                _ = try GrammarParser(language: grammar)
                try Expect.true(false, "precedence requires a dedicated native lowering")
            } catch GrammarParser.Failure.unsupported_precedence {}
        }
    }

    private static func emojiLanguage() throws -> Grammar.Language {
        try Grammar.Language(name: "emoji_assignments", start: "file", productions: [
            .init(name: "file", expression: .repeat1(.symbol(.production("item")))),
            .init(name: "item", expression: .sequence([
                .symbol(.terminal("glyph")),
                .field("name", .symbol(.terminal("identifier")))
            ]))
        ], terminals: [
            .init(name: "glyph", pattern: .literal("\u{1F415}"), role: "keyword"),
            .init(name: "identifier", pattern: .regex("[a-z]+"), role: "variable")
        ], extras: [.pattern("[ \\t\\r\\n]+")])
    }

    private static func language() throws -> Grammar.Language {
        try Grammar.Language(name: "assignment", start: "file", productions: [
            .init(name: "file", expression: .repeat1(.symbol(.production("assignment")))),
            .init(name: "assignment", expression: .sequence([
                .symbol(.terminal("let_keyword")),
                .field("name", .symbol(.terminal("identifier"))),
                .literal("="),
                .field("value", .symbol(.terminal("identifier")))
            ]))
        ], terminals: [
            .init(name: "let_keyword", pattern: .literal("let"), role: "keyword"),
            .init(name: "identifier", pattern: .regex("[a-z]+"), role: "variable")
        ], extras: [.pattern("[ \\t\\r\\n]+")], word: "identifier")
    }
}
