import Foundation
import enum Grammar.Grammar
import GrammarTreeSitter
import GrammarParsing
import Testing

/// Cross-backend fixtures for the *supported* non-left-recursive grammar subset.
enum GrammarBackendParity {
    static func run(_ language: Grammar.Language) throws {
        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent("native-tree-sitter-parity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workspace) }

        let src = workspace.appendingPathComponent("src", isDirectory: true)
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        let artifacts = try GrammarTreeSitter.emit(language)
        try write(artifacts.grammarJSON, to: src.appendingPathComponent("grammar.json"))
        try write(#"{"name":"tree-sitter-assignment","version":"0.1.0"}"#,
                  to: workspace.appendingPathComponent("package.json"))
        let configuration = #"""
        {
            "grammars": [
                {
                    "name": "assignment",
                    "scope": "source.assignment",
                    "path": ".",
                    "file-types": ["assignment"]
                }
            ],
            "metadata": {
                "version": "0.1.0",
                "authors": [{"name": "Grammar Conformance"}]
            }
        }
        """#
        try write(configuration, to: workspace.appendingPathComponent("tree-sitter.json"))

        let generated = try command(["generate", "src/grammar.json"], in: workspace)
        try Expect.equal(generated.status, 0, "Tree-sitter generation: \(generated.output)")

        let parser = try GrammarParser(language: language)
        let cases: [(source: String, valid: Bool)] = [
            ("let alpha = beta\nlet gamma = delta", true),
            ("let z = y", true),
            ("let = beta", false),
            ("let alpha = ", false),
            ("let alpha = \u{1F415}", false)
        ]
        for (index, fixture) in cases.enumerated() {
            let filename = workspace.appendingPathComponent("fixture-\(index).assignment")
            try write(fixture.source, to: filename)
            let nativeAccepted = (try? parser.parse(fixture.source)) != nil
            let parsed = try command(
                ["parse", "--grammar-path", workspace.path, filename.path], in: workspace
            )
            let sitterAccepted = parsed.status == 0
                && !parsed.output.contains("(ERROR")
                && !parsed.output.contains("(MISSING")
            try Expect.equal(nativeAccepted, fixture.valid, "native fixture \(index)")
            try Expect.equal(sitterAccepted, fixture.valid,
                             "Tree-sitter fixture \(index): \(parsed.output)")
            if fixture.valid && index == 0 {
                let assignments = parsed.output.components(separatedBy: "(assignment").count - 1
                try Expect.equal(assignments, 2, "two Tree-sitter assignment nodes")
                try Expect.true(parsed.output.contains("name:"), "name field projection")
                try Expect.true(parsed.output.contains("value:"), "value field projection")
            }
        }
    }

    private static func write(_ content: String, to path: URL) throws {
        try content.write(to: path, atomically: true, encoding: .utf8)
    }

    private static func command(_ args: [String], in workspace: URL) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["tree-sitter"] + args
        process.currentDirectoryURL = workspace
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return .init(status: process.terminationStatus,
                     output: String(decoding: data, as: UTF8.self))
    }

    private struct CommandResult {
        let status: Int32
        let output: String
    }
}
