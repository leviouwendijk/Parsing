import Foundation
import Position

public struct Diagnostic: Sendable, Codable, Hashable, CustomStringConvertible {
    public enum Severity: String, Sendable, Codable, Hashable {
        case error
        case warning
        case note
    }

    public let message: String
    public let severity: Severity
    public let range: PositionRange?
    /// If true, alternatives and optional/repetition combinators must not discard this failure.
    public let committed: Bool

    public init(
        _ message: String,
        severity: Severity = .error,
        range: PositionRange? = nil,
        committed: Bool = false
    ) {
        self.message = message
        self.severity = severity
        self.range = range
        self.committed = committed
    }

    public var description: String {
        if let range {
            return "\(severity): \(message) [\(range.start.offset)-\(range.end.offset)]"
        }

        return "\(severity): \(message)"
    }

    public func render(using cursor: TokenCursor) -> String {
        guard let range, let position = cursor.position(at: range.start) else {
            return description
        }

        return "\(severity): \(message) @ \(position)"
    }
}
