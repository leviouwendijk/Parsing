import Position

public enum StructuredParser {}

public extension StructuredParser {
    indirect enum Specification: Sendable, Codable, Hashable {
        case literal(String)
        case identifier
        case sequence([Specification])
        case choice([Specification])
        case optional(Specification)
        case repetition(
            specification: Specification,
            minimum: Int,
            maximum: Int?
        )
        case capture(
            name: String,
            specification: Specification
        )
        case until(Specification)
        case balanced(
            opening: String,
            closing: String
        )
        case reference(String)
    }

    struct Capture: Sendable, Codable, Hashable {
        public let name: String
        public let value: String
        public let range: PositionRange

        public init(
            name: String,
            value: String,
            range: PositionRange
        ) {
            self.name = name
            self.value = value
            self.range = range
        }
    }

    struct Match: Sendable, Codable, Hashable {
        public let range: PositionRange
        public let captures: [Capture]

        public init(
            range: PositionRange,
            captures: [Capture] = []
        ) {
            self.range = range
            self.captures = captures
        }
    }

    enum Cardinality:
        Sendable,
        Codable,
        Hashable,
        CustomStringConvertible
    {
        case exactly(Int)
        case atLeast(Int)
        case atMost(Int)

        public static var exactlyOne: Self {
            .exactly(1)
        }

        public var description: String {
            switch self {
            case .exactly(let count):
                return "exactly \(count)"

            case .atLeast(let count):
                return "at least \(count)"

            case .atMost(let count):
                return "at most \(count)"
            }
        }

        public func accepts(
            _ count: Int
        ) -> Bool {
            switch self {
            case .exactly(let expected):
                return count == expected

            case .atLeast(let minimum):
                return count >= minimum

            case .atMost(let maximum):
                return count <= maximum
            }
        }

        fileprivate var count: Int {
            switch self {
            case .exactly(let count),
                 .atLeast(let count),
                 .atMost(let count):
                return count
            }
        }
    }

    enum ValidationError:
        Error,
        Sendable,
        Codable,
        Hashable,
        CustomStringConvertible
    {
        case emptyLiteral
        case emptySequence
        case emptyChoice
        case emptyCaptureName
        case invalidRepetition(
            minimum: Int,
            maximum: Int?
        )
        case nonConsumingRepetition
        case nullableUntilTerminator
        case invalidBalancedDelimiters(
            opening: String,
            closing: String
        )
        case emptyReferenceName
        case referenceRequiresGrammar(String)
        case emptyDefinitionName
        case duplicateDefinition(String)
        case undefinedReference(String)
        case recursiveReference([String])

        public var description: String {
            switch self {
            case .emptyLiteral:
                return "Literal specifications cannot be empty."

            case .emptySequence:
                return "Sequence specifications must contain at least one child."

            case .emptyChoice:
                return "Choice specifications must contain at least one alternative."

            case .emptyCaptureName:
                return "Capture names cannot be empty."

            case .invalidRepetition(let minimum, let maximum):
                let maximumDescription = maximum.map(String.init) ?? "unbounded"
                return "Invalid repetition bounds: minimum=\(minimum), maximum=\(maximumDescription)."

            case .nonConsumingRepetition:
                return "Repetition cannot contain a specification that may succeed without consuming input."

            case .nullableUntilTerminator:
                return "Until requires a terminator that cannot succeed without consuming input."

            case .invalidBalancedDelimiters(let opening, let closing):
                return "Balanced delimiters must be non-empty and distinct: opening='\(opening)', closing='\(closing)'."

            case .emptyReferenceName:
                return "Structured parser reference names cannot be empty."

            case .referenceRequiresGrammar(let name):
                return "Structured parser reference '\(name)' requires StructuredParser.Grammar scope."

            case .emptyDefinitionName:
                return "Structured parser grammar definition names cannot be empty."

            case .duplicateDefinition(let name):
                return "Structured parser grammar contains duplicate definition '\(name)'."

            case .undefinedReference(let name):
                return "Structured parser grammar reference '\(name)' is undefined."

            case .recursiveReference(let path):
                return "Structured parser grammar contains a recursive reference cycle: \(path.joined(separator: " -> "))."
            }
        }
    }

    enum CardinalityError:
        Error,
        Sendable,
        Codable,
        Hashable,
        CustomStringConvertible
    {
        case invalid(Cardinality)
        case unsatisfied(
            expected: Cardinality,
            actual: Int
        )

        public var description: String {
            switch self {
            case .invalid(let cardinality):
                return "Invalid structured parser cardinality: \(cardinality)."

            case .unsatisfied(let expected, let actual):
                return "Structured parser expected \(expected) match(es), found \(actual)."
            }
        }
    }

    struct Compiled: Sendable, Hashable {
        public let specification: Specification

        init(
            specification: Specification
        ) {
            self.specification = specification
        }
    }
}

public extension StructuredParser.Cardinality {
    func validate(
        _ count: Int
    ) throws {
        guard self.count >= 0 else {
            throw StructuredParser.CardinalityError.invalid(self)
        }

        guard accepts(count) else {
            throw StructuredParser.CardinalityError.unsatisfied(
                expected: self,
                actual: count
            )
        }
    }
}
