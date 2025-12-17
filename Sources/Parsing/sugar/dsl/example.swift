// entry {
//   date = 2025-01-20
//   line { account = 10201; amount = 50.00 }
//   line { account = 70000; amount = 30.00 }
// }

// // Register leaves
// var parserComps = ParserComponents()
// parserComps.register("identifier") { TokenParsers.identifier() }
// parserComps.register("string") { TokenParsers.string() }
// parserComps.register("decimal") { /* as above */  }
// parserComps.register("int") { /* ... */  }

// // Declare nodes (no Accounting types here, just shapes)
// let lineNode = GNode(
//     name: "line",
//     opener: .raw("line"),
//     delimiter: .braces,
//     order: .unordered,
//     fields: [
//         GField("account", .val("identifier")),
//         GField("amount", .val("decimal")),
//     ]
// )

// let entryNode = GNode(
//     name: "entry",
//     opener: .raw("entry"),
//     delimiter: .braces,
//     order: .unordered,
//     fields: [
//         GField("date", .val("string"), required: false),
//         GField("line", .node("line"), required: true, repeated: true),
//     ]
// )

// let grammar = Grammar(
//     nodes: [entryNode, lineNode],
//     values: V,
//     child: { /* open recursion fallback if you want nested unknowns */
//         AnyTokenParser { .failure(Diagnostic("no child")) }
//     }
// )

// let parser = GrammarCompiler.compile(grammar, node: "entry")  // AnyTokenParser<GResult>
