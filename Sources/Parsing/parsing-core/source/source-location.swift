import Foundation

// public struct SourceLocation: Sendable, Hashable {
//     public let offset: Int
//     public init(_ offset: Int) { self.offset = offset }
// }

public struct SourceLocation: CustomStringConvertible, Codable, Sendable, Hashable {
    public let file: String?
    public let line: Int
    public let column: Int
    public let invocation: InvocationCallSite?

    public init(file: String? = nil, line: Int, column: Int, invocation: InvocationCallSite? = nil) {
        self.file = file
        self.line = line
        self.column = column
        self.invocation = invocation
    }

    public var description: String {
        let base = (file != nil) ? "\(file!):\(line):\(column)" : "\(line):\(column)"
        if let inv = invocation, !inv.description.isEmpty { return base + " " + inv.description }
        return base
    }
}

public extension Optional where Wrapped == SourceLocation {
    var describeSuffix: String {
        switch self { case .some(let loc): return " at \(loc)"; case .none: return "" }
    }
}
