import Foundation

public extension Lexer {
    mutating func readQuotedLiteral() -> String {
        // assumes opening " already consumed
        var out = String.UnicodeScalarView()
        while let s = peek() {
            advance()
            if s == "\"" { break }
            if s == "\\" { // simple escapes
                if let n = peek() {
                    advance()
                    switch n {
                    case "n": out.append("\n")
                    case "t": out.append("\t")
                    case "\"": out.append("\"")
                    case "\\": out.append("\\")
                    default: out.append(n)
                    }
                    continue
                } else { break }
            }
            out.append(s)
        }
        return String(out)
    }

    mutating func readUntilClosing(
        delimiter: Delimiter,
        options: BlockStringOptions
    ) -> String {
        var depth = 1
        var out = String.UnicodeScalarView()

        while let _ = peek() {
            // Lookahead for end without consuming
            let endScalars = Array(delimiter.end.unicodeScalars)
            if index + endScalars.count <= scalars.count {
                var isEnd = true
                for (k, ch) in endScalars.enumerated() where scalars[index + k] != ch {
                    isEnd = false; break
                }
                if isEnd {
                    if depth == 1 {
                        // This is the final closing delimiter: DO NOT consume here.
                        break
                    } else {
                        // Consume inner closing text and keep it in output.
                        for _ in endScalars { advance() }
                        depth -= 1
                        out.append(contentsOf: delimiter.end.unicodeScalars)
                        continue
                    }
                }
            }

            // Nested start?
            let startScalars = Array(delimiter.start.unicodeScalars)
            if delimiter.allowsNesting,
               index + startScalars.count <= scalars.count {
                var isStart = true
                for (k, ch) in startScalars.enumerated() where scalars[index + k] != ch {
                    isStart = false; break
                }
                if isStart {
                    for _ in startScalars { advance() }
                    depth += 1
                    out.append(contentsOf: delimiter.start.unicodeScalars)
                    continue
                }
            }

            // Otherwise, copy one scalar
            if let u = peek() { out.append(u); advance() }
        }

        var s = String(out)
        if options.normalizeNewlines {
            s = s.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        }
        if options.trimWhitespace {
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if options.unquoteIfWrapped, s.count >= 2, s.first == "\"", s.last == "\"" {
            s = unescapeQuotedPayload(String(s.dropFirst().dropLast()), options: options)
        }
        return s
    }

    @inline(__always)
    mutating func unescapeQuotedPayload(_ payload: String, options: BlockStringOptions) -> String {
        guard options.unescapeCommon else { return payload }
        // simple escapes: \n \t \" \\
        let scalars = Array(payload.unicodeScalars)
        var out = String.UnicodeScalarView()
        var i = 0
        while i < scalars.count {
            let s = scalars[i]
            if s == "\\", i + 1 < scalars.count {
                let n = scalars[i+1]
                switch n {
                case "n":  out.append("\n"); i += 2; continue
                case "t":  out.append("\t"); i += 2; continue
                case "\"": out.append("\""); i += 2; continue
                case "\\": out.append("\\"); i += 2; continue
                default:   out.append(n);    i += 2; continue
                }
            } else { out.append(s); i += 1 }
        }
        return String(out)
    }

    @available(*, message: "superseded by generic readUntilClosing(delimiter:, options:)")
    mutating func readUntilClosingBraceVerbatim() -> String {
        var depth = 0
        var out = String.UnicodeScalarView()
        while let s = peek() {
            if s == "{" { depth += 1; out.append(s); advance(); continue }
            if s == "}" {
                if depth == 0 { break }
                depth -= 1
                out.append(s); advance(); continue
            }
            out.append(s); advance()
        }
        return String(out)
    }

    @available(*, message: "superseded by generic readUntilClosing(delimiter:, options:)")
    mutating func readUntilClosingBraceTrimmed() -> String {
        let v = readUntilClosingBraceVerbatim()
        return v.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @available(*, message: "superseded by generic readUntilClosing(delimiter:, options:)")
    mutating func readUntilClosingBraceTrimmedEscaped() -> String {
        let v = readUntilClosingBraceVerbatim()
        let t = v.trimmingCharacters(in: .whitespacesAndNewlines)

        guard t.count >= 2, t.first == "\"", t.last == "\"" else { return t }

        let scalars = Array(t.unicodeScalars)
        var out = String.UnicodeScalarView()
        var i = 1                           // skip leading quote
        let end = scalars.count - 1         // skip trailing quote
        while i < end {
            let s = scalars[i]
            if s == "\\", i + 1 < end {
                let n = scalars[i+1]
                switch n {
                case "n":  out.append("\n"); i += 2; continue
                case "t":  out.append("\t"); i += 2; continue
                case "\"": out.append("\""); i += 2; continue
                case "\\": out.append("\\"); i += 2; continue
                default:   out.append(n);    i += 2; continue
                }
            } else {
                out.append(s); i += 1
            }
        }
        return String(out)
    }

    @available(*, message: "possibly superseded by readNumberRawAndValue")
    mutating func readNumber() -> Decimal {
        var buf = String.UnicodeScalarView()
        var sawDot = false
        while let s = peek() {
            if CharacterSet.decimalDigits.contains(s) {
                buf.append(s); advance(); continue
            }
            if s == "." && !sawDot {
                sawDot = true; buf.append(s); advance(); continue
            }
            break
        }
        return Decimal(string: String(buf)) ?? 0
    }

    mutating func readNumberRawAndValue() -> (raw: String, value: Decimal) {
        var buf = String.UnicodeScalarView()
        var sawDot = false
        while let s = peek() {
            if CharacterSet.decimalDigits.contains(s) { buf.append(s); advance(); continue }
            if s == "." && !sawDot { sawDot = true; buf.append(s); advance(); continue }
            break
        }
        let raw = String(buf)
        return (raw, Decimal(string: raw) ?? 0)
    }

    // @inlinable
    // mutating func readInteger() throws -> Int {
    //     // assuming lexer already has readNumberRawAndValue()
    //     let (raw, dec) = readNumberRawAndValue()
    //     // dec is Decimal
    //     var intValue = NSDecimalNumber(decimal: dec).intValue
    //     // verify no fractional part
    //     let fractional = dec - Decimal(intValue)
    //     if fractional != Decimal(0) {
    //         throw ParserError.unexpectedToken(.number(dec, raw: raw), expected: "integer", at: loc())
    //     }
    //     return intValue
    // }

    mutating func readIdent() -> String {
        var buf = String.UnicodeScalarView()
        func isHead(_ s: UnicodeScalar) -> Bool {
            CharacterSet.letters.contains(s) || s == "_"
        }
        func isCont(_ s: UnicodeScalar) -> Bool {
            CharacterSet.letters.contains(s) || CharacterSet.decimalDigits.contains(s) ||
            s == "_" || s == "-" || s == "."
        }
        // head
        if let s = peek(), isHead(s) { buf.append(s); advance() }
        // tail
        while let s = peek(), isCont(s) { buf.append(s); advance() }
        return String(buf)
    }

    /// Fast path for date-like literals; return nil to skip if not sure.
    mutating func scanDateLiteral() -> String? {
        // minimal stub: recognize YYYY-MM-DD or YYYY/MM/DD
        let start = index
        var buf = String.UnicodeScalarView()
        func rollback() { index = start } // line/column drift is harmless for tokens

        // need 10 or more chars
        for _ in 0..<10 {
            guard let s = peek() else { rollback(); return nil }
            buf.append(s); advance()
        }
        let s = String(buf)
        let re = try! NSRegularExpression(pattern: #"^\d{4}[-/\.]\d{2}[-/\.]\d{2}"#)
        if re.firstMatch(in: s, range: NSRange(location: 0, length: s.utf16.count)) != nil {
            // extend greedily over remaining digits/sep
            while let u = peek(), CharacterSet.decimalDigits.contains(u) || u == "-" || u == "/" || u == "." {
                buf.append(u); advance()
            }
            return String(buf)
        }
        rollback()
        return nil
    }

    mutating func readWhitespaceRun() -> String? {
        var out = String.UnicodeScalarView()
        var consumed = false
        while let s = peek(), s == " " || s == "\t" || s == "\r" {
            out.append(s); advance(); consumed = true
        }
        return consumed ? String(out) : nil
    }

    /// Consume one newline. If `normalize` is true, CRLF is normalized into a single newline.
    /// Returns true if a newline was consumed.
    mutating func readNormalizedNewline(_ normalize: Bool) -> Bool {
        guard let s = peek() else { return false }
        if s == "\n" { advance(); return true }
        if s == "\r" {
            if normalize, peek(aheadBy: 1) == "\n" { advance(); advance(); return true }
            advance(); return true
        }
        return false
    }

    /// Try to read a comment using the configured signatures. Returns a comment token if matched.
    mutating func readComment(_ sigs: [CommentSignature]) -> Token? {
        guard peek() != nil else { return nil }

        for sig in sigs {
            switch sig {
            case .line(let prefix):
                if match(prefix) {
                    var out = String.UnicodeScalarView()
                    while let u = peek(), u != "\n", u != "\r" { out.append(u); advance() }
                    return .comment_line(String(out))
                }

            case .block(let start, let end, let allows_nesting):
                if match(start) {
                    var depth = 1
                    var out = String.UnicodeScalarView()
                    while let _ = peek() {
                        if match(end) {
                            depth -= 1
                            if depth == 0 { break }
                            continue
                        }
                        if allows_nesting, match(start) { depth += 1; continue }
                        out.append(peek()!); advance()
                    }
                    return .comment_block(String(out))
                }
            }
        }
        return nil
    }

    /// Match a multi-scalar string; advances if it matches at the current position.
    @inline(__always)
    mutating func match(_ str: String) -> Bool {
        let u = Array(str.unicodeScalars)
        guard index + u.count <= scalars.count else { return false }
        for (k, ch) in u.enumerated() where scalars[index + k] != ch { return false }
        for _ in u { advance() }
        return true
    }
}
