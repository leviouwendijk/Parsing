import Testing

enum ParsingTestSuite {
    static let suite = TestSuite(
        "parsing",
        title: "Parsing tests"
    ) {
        lexicalProvenanceSuite
        tokenCursorProvenanceSuite
        tokenCodableSuite
        tokenCompatibilitySuite
        structuredParserSuite
        structuredParserScanningSuite
        structuredParserGrammarSuite
        structuredParserRequiredAnchorSuite
    }
}
