import Foundation
import Position

public struct Lexer: Lexing, PositionedLexing {
    public let source: String
    public let scalars: [UnicodeScalar]
    public var index: Int = 0
    public var line: Int = 1
    public var column: Int = 1
    public var string_block_state: LexStringBlockState = .none

    private var activeBlockPolicy: BlockStringPolicy? = nil
    private let scalarBoundaryStartCharacterOffsets: [Int]
    private let scalarBoundaryEndCharacterOffsets: [Int]

    public let sets: LexingSets
    public let options: LexerOptions
    public let config: LexerConfig

    public init(
        source: String,
        sets: LexingSets,
        options: LexerOptions = .init(),
        config: LexerConfig = .init()
    ) {
        self.source = source
        self.scalars = Array(source.unicodeScalars)

        let offsets = Self.characterOffsetsByScalarBoundary(source)
        self.scalarBoundaryStartCharacterOffsets = offsets.start
        self.scalarBoundaryEndCharacterOffsets = offsets.end
        self.sets = sets
        self.options = options
        self.config = config
    }

    public mutating func nextLexedToken() -> LexedToken {
        nextLexeme()
    }

    public mutating func nextToken() -> Token {
        nextLexeme().token
    }

    private mutating func nextLexeme() -> LexedToken {
        switch string_block_state {
        case .awaitingOpen:
            while true {
                let start = index
                if let whitespace = readWhitespaceRun() {
                    if options.emit_whitespace {
                        return emitted(.whitespace(whitespace), fromScalarBoundary: start)
                    }
                    continue
                }

                let newlineStart = index
                if readNormalizedNewline(options.normalize_newlines) {
                    if options.emit_newlines {
                        return emitted(.newline, fromScalarBoundary: newlineStart)
                    }
                    continue
                }

                let commentStart = index
                if let comment = readComment(options.comments) {
                    if options.emit_comments {
                        return emitted(comment, fromScalarBoundary: commentStart)
                    }
                    continue
                }

                break
            }

            let policy = activeBlockPolicy ?? options.block_string_policies.fallback
            let start = index
            guard match(policy.delimiter.start) else {
                return emitted(.eof, fromScalarBoundary: start)
            }

            string_block_state = .awaitingContent
            return emitted(leftToken(for: policy.delimiter), fromScalarBoundary: start)

        case .awaitingContent:
            let policy = activeBlockPolicy ?? options.block_string_policies.fallback
            let start = index
            let text = readUntilClosing(
                delimiter: policy.delimiter,
                options: policy.options
            )
            string_block_state = .awaitingClose
            return emitted(.string(text), fromScalarBoundary: start)

        case .awaitingClose:
            while true {
                let start = index
                if let whitespace = readWhitespaceRun() {
                    if options.emit_whitespace {
                        return emitted(.whitespace(whitespace), fromScalarBoundary: start)
                    }
                    continue
                }

                let newlineStart = index
                if readNormalizedNewline(options.normalize_newlines) {
                    if options.emit_newlines {
                        return emitted(.newline, fromScalarBoundary: newlineStart)
                    }
                    continue
                }

                let commentStart = index
                if let comment = readComment(options.comments) {
                    if options.emit_comments {
                        return emitted(comment, fromScalarBoundary: commentStart)
                    }
                    continue
                }

                break
            }

            let policy = activeBlockPolicy ?? options.block_string_policies.fallback
            let start = index
            guard match(policy.delimiter.end) else {
                return emitted(.eof, fromScalarBoundary: start)
            }

            string_block_state = .none
            defer { activeBlockPolicy = nil }
            return emitted(rightToken(for: policy.delimiter), fromScalarBoundary: start)

        case .none:
            break
        }

        let whitespaceStart = index
        if let whitespace = readWhitespaceRun(), options.emit_whitespace {
            return emitted(.whitespace(whitespace), fromScalarBoundary: whitespaceStart)
        }

        let newlineStart = index
        if readNormalizedNewline(options.normalize_newlines), options.emit_newlines {
            return emitted(.newline, fromScalarBoundary: newlineStart)
        }

        let commentStart = index
        if let comment = readComment(options.comments), options.emit_comments {
            return emitted(comment, fromScalarBoundary: commentStart)
        }

        let dateStart = index
        if let literal = scanDateLiteral() {
            return emitted(.date_literal(literal), fromScalarBoundary: dateStart)
        }

        let start = index
        guard let scalar = peek() else {
            return emitted(.eof, fromScalarBoundary: start)
        }

        if scalar == "\"" {
            advance()
            return emitted(.string(readQuotedLiteral()), fromScalarBoundary: start)
        }

        switch scalar {
        case "{": advance(); return emitted(.left_brace, fromScalarBoundary: start)
        case "}": advance(); return emitted(.right_brace, fromScalarBoundary: start)
        case "(": advance(); return emitted(.left_parenthesis, fromScalarBoundary: start)
        case ")": advance(); return emitted(.right_parenthesis, fromScalarBoundary: start)
        case "[": advance(); return emitted(.left_bracket, fromScalarBoundary: start)
        case "]": advance(); return emitted(.right_bracket, fromScalarBoundary: start)
        case "-":
            if peek(aheadBy: 1) == ">" {
                advance(); advance()
                return emitted(.arrow, fromScalarBoundary: start)
            }
        case "<": advance(); return emitted(.less_than, fromScalarBoundary: start)
        case ">": advance(); return emitted(.greater_than, fromScalarBoundary: start)
        case ".": advance(); return emitted(.dot, fromScalarBoundary: start)
        case "=": advance(); return emitted(.equals, fromScalarBoundary: start)
        case ",": advance(); return emitted(.comma, fromScalarBoundary: start)
        case "#": advance(); return emitted(.hash, fromScalarBoundary: start)
        case "$": advance(); return emitted(.dollar, fromScalarBoundary: start)
        case "/": advance(); return emitted(.forward_slash, fromScalarBoundary: start)
        case "\\": advance(); return emitted(.backward_slash, fromScalarBoundary: start)
        case "'": advance(); return emitted(.single_quote, fromScalarBoundary: start)
        case "\"": advance(); return emitted(.double_quote, fromScalarBoundary: start)
        case "@": advance(); return emitted(.at, fromScalarBoundary: start)
        case "%": advance(); return emitted(.percent, fromScalarBoundary: start)
        case "*": advance(); return emitted(.asterisk, fromScalarBoundary: start)
        case "&": advance(); return emitted(.ampersand, fromScalarBoundary: start)
        case "+": advance(); return emitted(.plus, fromScalarBoundary: start)
        case "_": advance(); return emitted(.underscore, fromScalarBoundary: start)
        case "~": advance(); return emitted(.tilde, fromScalarBoundary: start)
        case ":": advance(); return emitted(.colon, fromScalarBoundary: start)
        case ";": advance(); return emitted(.semicolon, fromScalarBoundary: start)
        case "|": advance(); return emitted(.pipe, fromScalarBoundary: start)
        default: break
        }

        if CharacterSet.decimalDigits.contains(scalar) {
            let (raw, value) = readNumberRawAndValue()
            return emitted(.number(value, raw: raw), fromScalarBoundary: start)
        }

        if CharacterSet.letters
            .union(CharacterSet(charactersIn: "_"))
            .contains(scalar)
        {
            let identifier = readIdent()

            if sets.stringBlockKeywords.contains(identifier) {
                activeBlockPolicy = options.block_string_policies.policy(for: identifier)
                string_block_state = .awaitingOpen
                return emitted(.keyword(identifier), fromScalarBoundary: start)
            }

            if sets.keywords.contains(identifier) {
                return emitted(.keyword(identifier), fromScalarBoundary: start)
            }

            return emitted(.identifier(identifier), fromScalarBoundary: start)
        }

        advance()
        return nextLexeme()
    }

    @inline(__always)
    private func leftToken(for delimiter: Delimiter) -> Token {
        switch delimiter.start {
        case "{": return .left_brace
        case "[": return .left_bracket
        case "(": return .left_parenthesis
        case "<": return .less_than
        default: return .left_brace
        }
    }

    @inline(__always)
    private func rightToken(for delimiter: Delimiter) -> Token {
        switch delimiter.end {
        case "}": return .right_brace
        case "]": return .right_bracket
        case ")": return .right_parenthesis
        case ">": return .greater_than
        default: return .right_brace
        }
    }

    @inlinable
    public func loc(
        file: String? = nil,
        columnOverride: Int? = nil
    ) -> Position {
        Position(
            uncheckedFile: file,
            line: line,
            column: columnOverride ?? column,
            invocation: nil
        )
    }

    @inline(__always)
    mutating func error(_ message: String) throws -> Token {
        let location = loc()

        switch config.errorStrategy {
        case .throwing:
            throw LexerError.message(message, at: location)
        case .error_token:
            return .error(message, at: location)
        case .diagnose_only(let sink):
            sink(message, location)
            return .eof
        }
    }
}

private extension Lexer {
    func emitted(
        _ token: Token,
        fromScalarBoundary start: Int
    ) -> LexedToken {
        LexedToken(
            token: token,
            range: PositionRange(
                uncheckedStart: .init(
                    characterStartOffset(atScalarBoundary: start)
                ),
                uncheckedEnd: .init(
                    characterEndOffset(atScalarBoundary: index)
                )
            )
        )
    }

    func characterStartOffset(atScalarBoundary boundary: Int) -> Int {
        let clamped = min(max(0, boundary), scalarBoundaryStartCharacterOffsets.count - 1)
        return scalarBoundaryStartCharacterOffsets[clamped]
    }

    func characterEndOffset(atScalarBoundary boundary: Int) -> Int {
        let clamped = min(max(0, boundary), scalarBoundaryEndCharacterOffsets.count - 1)
        return scalarBoundaryEndCharacterOffsets[clamped]
    }

    static func characterOffsetsByScalarBoundary(
        _ source: String
    ) -> (start: [Int], end: [Int]) {
        let scalarCount = source.unicodeScalars.count
        var starts = Array(repeating: 0, count: scalarCount + 1)
        var ends = starts
        var scalarOffset = 0
        var characterOffset = 0

        for character in source {
            let count = character.unicodeScalars.count

            for innerOffset in 0..<count {
                let boundary = scalarOffset + innerOffset
                starts[boundary] = characterOffset
                ends[boundary] = innerOffset == 0 ? characterOffset : characterOffset + 1
            }

            scalarOffset += count
            characterOffset += 1
            starts[scalarOffset] = characterOffset
            ends[scalarOffset] = characterOffset
        }

        return (starts, ends)
    }
}
