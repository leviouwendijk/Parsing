import Foundation

// public struct Diagnostic: Sendable, CustomStringConvertible {
//     public enum Severity: Sendable { case error, warning, note }
//     public let message: String
//     public let severity: Severity
//     public let range: SourceRange?

//     public init(_ message: String, severity: Severity = .error, range: SourceRange? = nil) {
//         self.message = message; self.severity = severity; self.range = range
//     }
//     public var description: String {
//         if let r = range { return "\(severity): \(message) [\(r.start.offset)-\(r.end.offset)]" }
//         return "\(severity): \(message)"
//     }
// }

public struct Diagnostic: Sendable, CustomStringConvertible {
    public enum Severity: Sendable { case error, warning, note }
    public let message: String
    public let severity: Severity
    public let range: SourceRange?

    public init(_ message: String, severity: Severity = .error, range: SourceRange? = nil) {
        self.message = message
        self.severity = severity
        self.range = range
    }

    public var description: String {
        if let r = range { return "\(severity): \(message) [\(r.start.offset)-\(r.end.offset)]" }
        return "\(severity): \(message)"
    }

    public func render(using cur: TokenCursor) -> String {
        if let lm = cur.lineMap, let r = range {
            let i = min(max(r.start.offset, 0), lm.count > 0 ? lm.count - 1 : 0)
            let line = lm.isEmpty ? 1 : lm[i]
            let loc = SourceLocation(file: cur.filePath, line: line, column: 1, invocation: nil)
            return "\(severity): \(message) @ \(loc)"
        }
        return description
    }
}
