import Testing

enum ParsingTestSuite {
    static let suite = TestSuite(
        "parsing",
        title: "Parsing tests"
    ) {
        tokenCursorProvenanceSuite
        canonicalLexingSuite
        publicAPISuite
        grammarCorrectnessSuite
        tokenCompatibilitySuite
        structuredParserSuite
        structuredParserScanningSuite
        structuredParserGrammarSuite
        structuredParserRequiredAnchorSuite
        parserInvarianceSuite
    }
}
