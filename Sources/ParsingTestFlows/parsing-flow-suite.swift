import TestFlows

enum ParsingFlowSuite: TestFlowRegistry {
    static let title = "Parsing flow tests"

    static let flows: [TestFlow] = [
        lexicalProvenanceFlow,
        tokenCursorProvenanceFlow,
        tokenCodableFlow,
        tokenCompatibilityFlow,
        structuredParserFlow,
        structuredParserScanningFlow,
        structuredParserGrammarFlow,
    ]
}
