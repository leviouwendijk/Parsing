import TestFlows

@main
enum ParsingTestCLI {
    static func main() async {
        await TestFlowCLI.run(
            suite: ParsingFlowSuite.self
        )
    }
}
