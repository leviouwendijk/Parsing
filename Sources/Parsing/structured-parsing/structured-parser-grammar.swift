public extension StructuredParser {
    struct Grammar: Sendable, Codable, Hashable {
        public struct Definition: Sendable, Codable, Hashable {
            public let name: String
            public let specification: Specification

            public init(
                name: String,
                specification: Specification
            ) {
                self.name = name
                self.specification = specification
            }
        }

        public let root: Specification
        public let definitions: [Definition]

        public init(
            root: Specification,
            definitions: [Definition] = []
        ) {
            self.root = root
            self.definitions = definitions
        }
    }
}

public extension StructuredParser.Grammar {
    func validate() throws {
        _ = try StructuredParserValidator.resolve(
            self
        )
    }

    func compile() throws -> StructuredParser.Compiled {
        StructuredParser.Compiled(
            specification: try StructuredParserValidator.resolve(
                self
            )
        )
    }
}
