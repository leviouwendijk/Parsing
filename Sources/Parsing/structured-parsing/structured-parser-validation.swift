public extension StructuredParser.Specification {
    func validate() throws {
        try StructuredParserValidator.validate(
            self,
            allowingReferences: false
        )
    }

    func compile() throws -> StructuredParser.Compiled {
        try validate()

        return StructuredParser.Compiled(
            specification: self
        )
    }
}

enum StructuredParserValidator {
    static func validate(
        _ specification: StructuredParser.Specification,
        allowingReferences: Bool
    ) throws {
        switch specification {
        case .literal(let value):
            guard !value.isEmpty else {
                throw StructuredParser.ValidationError.emptyLiteral
            }

        case .identifier:
            break

        case .sequence(let children):
            guard !children.isEmpty else {
                throw StructuredParser.ValidationError.emptySequence
            }

            for child in children {
                try validate(
                    child,
                    allowingReferences: allowingReferences
                )
            }

        case .choice(let alternatives):
            guard !alternatives.isEmpty else {
                throw StructuredParser.ValidationError.emptyChoice
            }

            for alternative in alternatives {
                try validate(
                    alternative,
                    allowingReferences: allowingReferences
                )
            }

        case .optional(let child):
            try validate(
                child,
                allowingReferences: allowingReferences
            )

        case .repetition(
            let child,
            let minimum,
            let maximum
        ):
            guard
                minimum >= 0,
                maximum.map({ $0 >= minimum }) ?? true
            else {
                throw StructuredParser.ValidationError.invalidRepetition(
                    minimum: minimum,
                    maximum: maximum
                )
            }

            try validate(
                child,
                allowingReferences: allowingReferences
            )

            if maximum != 0, isNullable(child) {
                throw StructuredParser.ValidationError.nonConsumingRepetition
            }

        case .capture(let name, let child):
            guard !name.isEmpty else {
                throw StructuredParser.ValidationError.emptyCaptureName
            }

            try validate(
                child,
                allowingReferences: allowingReferences
            )

        case .until(let terminator):
            try validate(
                terminator,
                allowingReferences: allowingReferences
            )

            guard !isNullable(terminator) else {
                throw StructuredParser.ValidationError.nullableUntilTerminator
            }

        case .balanced(let opening, let closing):
            guard
                !opening.isEmpty,
                !closing.isEmpty,
                opening != closing
            else {
                throw StructuredParser.ValidationError.invalidBalancedDelimiters(
                    opening: opening,
                    closing: closing
                )
            }

        case .reference(let name):
            guard !name.isEmpty else {
                throw StructuredParser.ValidationError.emptyReferenceName
            }

            guard allowingReferences else {
                throw StructuredParser.ValidationError.referenceRequiresGrammar(
                    name
                )
            }
        }
    }

    static func resolve(
        _ grammar: StructuredParser.Grammar
    ) throws -> StructuredParser.Specification {
        var definitions: [String: StructuredParser.Specification] = [:]

        for definition in grammar.definitions {
            guard !definition.name.isEmpty else {
                throw StructuredParser.ValidationError.emptyDefinitionName
            }

            guard definitions[definition.name] == nil else {
                throw StructuredParser.ValidationError.duplicateDefinition(
                    definition.name
                )
            }

            definitions[definition.name] = definition.specification
        }

        for definition in grammar.definitions {
            try validate(
                definition.specification,
                allowingReferences: true
            )

            let resolved = try resolve(
                definition.specification,
                definitions: definitions,
                stack: [definition.name]
            )

            try validate(
                resolved,
                allowingReferences: false
            )
        }

        try validate(
            grammar.root,
            allowingReferences: true
        )

        let root = try resolve(
            grammar.root,
            definitions: definitions,
            stack: []
        )

        try validate(
            root,
            allowingReferences: false
        )

        return root
    }

    static func isNullable(
        _ specification: StructuredParser.Specification
    ) -> Bool {
        switch specification {
        case .literal, .identifier, .balanced, .reference:
            return false

        case .sequence(let children):
            return children.allSatisfy(isNullable)

        case .choice(let alternatives):
            return alternatives.contains(
                where: isNullable
            )

        case .optional:
            return true

        case .repetition(
            let child,
            let minimum,
            _
        ):
            return minimum == 0 || isNullable(child)

        case .capture(_, let child):
            return isNullable(child)

        case .until:
            return true
        }
    }

    private static func resolve(
        _ specification: StructuredParser.Specification,
        definitions: [String: StructuredParser.Specification],
        stack: [String]
    ) throws -> StructuredParser.Specification {
        switch specification {
        case .literal, .identifier, .balanced:
            return specification

        case .sequence(let children):
            return .sequence(
                try children.map {
                    try resolve(
                        $0,
                        definitions: definitions,
                        stack: stack
                    )
                }
            )

        case .choice(let alternatives):
            return .choice(
                try alternatives.map {
                    try resolve(
                        $0,
                        definitions: definitions,
                        stack: stack
                    )
                }
            )

        case .optional(let child):
            return .optional(
                try resolve(
                    child,
                    definitions: definitions,
                    stack: stack
                )
            )

        case .repetition(
            let child,
            let minimum,
            let maximum
        ):
            return .repetition(
                specification: try resolve(
                    child,
                    definitions: definitions,
                    stack: stack
                ),
                minimum: minimum,
                maximum: maximum
            )

        case .capture(let name, let child):
            return .capture(
                name: name,
                specification: try resolve(
                    child,
                    definitions: definitions,
                    stack: stack
                )
            )

        case .until(let terminator):
            return .until(
                try resolve(
                    terminator,
                    definitions: definitions,
                    stack: stack
                )
            )

        case .reference(let name):
            guard let definition = definitions[name] else {
                throw StructuredParser.ValidationError.undefinedReference(
                    name
                )
            }

            guard !stack.contains(name) else {
                throw StructuredParser.ValidationError.recursiveReference(
                    stack + [name]
                )
            }

            return try resolve(
                definition,
                definitions: definitions,
                stack: stack + [name]
            )
        }
    }
}
