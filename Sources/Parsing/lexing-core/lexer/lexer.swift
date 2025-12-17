import Foundation

public struct Lexer: Lexing {
    public let scalars: [UnicodeScalar]
    public var index: Int = 0
    public var line: Int = 1
    public var column: Int = 1

    public var string_block_state: LexStringBlockState = .none

    private var activeBlockPolicy: BlockStringPolicy? = nil

    public let sets: LexingSets
    public let options: LexerOptions
    public let config: LexerConfig

    public init(
        source: String,
        sets: LexingSets,
        options: LexerOptions = .init(),
        config: LexerConfig = .init()
    ) {
        self.scalars = Array(source.unicodeScalars)
        self.sets = sets
        self.options = options
        self.config = config
    }

    public mutating func nextToken() -> Token {
        switch string_block_state {
        case .awaitingOpen:
            // Consume trivia as you already do
            while true {
                if let ws = readWhitespaceRun() {
                    if options.emit_whitespace { return .whitespace(ws) }; continue
                }
                if readNormalizedNewline(options.normalize_newlines) {
                    if options.emit_newlines { return .newline }; continue
                }
                if let cmt = readComment(options.comments) {
                    if options.emit_comments { return cmt }; continue
                }
                break
            }

            let p = activeBlockPolicy ?? options.block_string_policies.fallback
            guard match(p.delimiter.start) else { return .eof }  // <-- match advances on success
            string_block_state = .awaitingContent
            return leftToken(for: p.delimiter)   // see helper below

        case .awaitingContent:
            let p = activeBlockPolicy ?? options.block_string_policies.fallback
            let text = readUntilClosing(delimiter: p.delimiter, options: p.options)
            string_block_state = .awaitingClose
            return .string(text)

        case .awaitingClose:
            while true {
                if let ws = readWhitespaceRun() {
                    if options.emit_whitespace { return .whitespace(ws) }; continue
                }
                if readNormalizedNewline(options.normalize_newlines) {
                    if options.emit_newlines { return .newline }; continue
                }
                if let cmt = readComment(options.comments) {
                    if options.emit_comments { return cmt }; continue
                }
                break
            }
            let p = activeBlockPolicy ?? options.block_string_policies.fallback
            guard match(p.delimiter.end) else { return .eof }    // <-- eat matching closer
            string_block_state = .none
            defer { activeBlockPolicy = nil }                    // clear for next time
            return rightToken(for: p.delimiter)

        case .none:
            break
        }

        // Trivia handling (options-driven)
        if let ws = readWhitespaceRun() {
            if options.emit_whitespace { return .whitespace(ws) }
            // else fall through to keep scanning
        }

        if readNormalizedNewline(options.normalize_newlines) {
            if options.emit_newlines { return .newline }
            // else keep scanning
        }

        if let cmt = readComment(options.comments) {
            if options.emit_comments { return cmt }
            // else keep scanning
        }

        // Fast-path date literal
        if let lit = scanDateLiteral() { return .date_literal(lit) }

        // End of input?
        guard let c = peek() else { return .eof }

        // Quoted string (outside block mode): "...."
        if c == "\"" {
            advance()
            return .string(readQuotedLiteral())
        }

        // Punctuation & symbols
        switch c {
        case "{": advance(); return .left_brace
        case "}": advance(); return .right_brace
        case "(": advance(); return .left_parenthesis
        case ")": advance(); return .right_parenthesis
        case "[": advance(); return .left_bracket
        case "]": advance(); return .right_bracket
        case "-":
            if peek(aheadBy: 1) == ">" { advance(); advance(); return .arrow }
        case "<": advance(); return .less_than
        case ">": advance(); return .greater_than
        case ".": advance(); return .dot
        case "=": advance(); return .equals
        case ",": advance(); return .comma
        case "#": advance(); return .hash
        case "$": advance(); return .dollar
        case "/": advance(); return .forward_slash
        case "\\": advance(); return .backward_slash
        case "'": advance(); return .single_quote
        case "\"": advance(); return .double_quote // (unreachable here because we handle strings above)
        case "@": advance(); return .at
        case "%": advance(); return .percent
        case "*": advance(); return .asterisk
        case "&": advance(); return .ampersand
        case "+": advance(); return .plus
        case "_": advance(); return .underscore
        case "~": advance(); return .tilde
        case ":": advance(); return .colon
        case ";": advance(); return .semicolon
        case "|": advance(); return .pipe
        default: break
        }

        // Number
        if CharacterSet.decimalDigits.contains(c) {
            let (raw, val) = readNumberRawAndValue()
            return .number(val, raw: raw)
        }

        // Identifier / Keyword / String-block trigger
        if CharacterSet.letters.union(CharacterSet(charactersIn: "_")).contains(c) {
            let ident = readIdent()
            if sets.stringBlockKeywords.contains(ident) {
                // pick policy for this keyword
                activeBlockPolicy = options.block_string_policies.policy(for: ident)
                string_block_state = .awaitingOpen
                return .keyword(ident)
            } else if sets.keywords.contains(ident) {
                return .keyword(ident)
            } else {
                if sets.idents.contains(ident) { return .identifier(ident) }
                return .identifier(ident)
            }
        }

        // Fallback: consume one scalar and continue
        advance()
        return nextToken()
    }

    @inline(__always)
    private func leftToken(for d: Delimiter) -> Token {
        switch d.start {
        case "{": return .left_brace
        case "[": return .left_bracket
        case "(": return .left_parenthesis
        case "<": return .less_than
        default:  return .left_brace // sensible default for now
        }
    }

    @inline(__always)
    private func rightToken(for d: Delimiter) -> Token {
        switch d.end {
        case "}": return .right_brace
        case "]": return .right_bracket
        case ")": return .right_parenthesis
        case ">": return .greater_than
        default:  return .right_brace
        }
    }

    @inlinable
    public func loc(file: String? = nil, columnOverride: Int? = nil) -> SourceLocation {
        SourceLocation(
            file: file,
            line: self.line,
            column: columnOverride ?? self.column,
            invocation: nil
        )
    }

    @inline(__always)
    mutating func error(_ msg: String) throws -> Token {
        let loc = loc()
        switch config.errorStrategy {
        case .throwing:
            throw LexerError.message(msg, at: loc)
        case .error_token:
            return .error(msg, at: loc)
        case .diagnose_only(let sink):
            sink(msg, loc); return .eof
        }
    }
}
