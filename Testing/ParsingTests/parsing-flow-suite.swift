import Testing

enum ParsingTestSuite {
    static let suite = TestSuite(
        "parsing",
        title: "Parsing tests"
    ) {
        tokenCursorProvenanceSuite
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
