import Foundation

public enum InvocationCallSiteType: String, Codable, Sendable, Hashable {
    case structure
    case function
    case enumeration
}

public struct InvocationCallSite: CustomStringConvertible, Codable, Sendable, Hashable {
    public let file: String?
    public let type: InvocationCallSiteType?
    public let scope: String?

    public init(file: String?, type: InvocationCallSiteType?, scope: String?) {
        self.file = file
        self.type = type
        self.scope = scope
    }

    public var description: String {
        var parts: [String] = []
        if let t = type {
            switch t {
            case .structure:   parts.append("struct")
            case .function:    parts.append("func")
            case .enumeration: parts.append("enum")
            }
        }
        if let s = scope { parts.append(s) }
        if let f = file { parts.append("@\(f)") }
        guard !parts.isEmpty else { return "" }
        return "[" + parts.joined(separator: " ") + "]"
    }
}

public extension InvocationCallSite {
    static func structure(_ scope: String, file: String? = nil) -> Self {
        .init(file: file, type: .structure, scope: scope)
    }
    static func function(_ scope: String, file: String? = nil) -> Self {
        .init(file: file, type: .function, scope: scope)
    }
    static func enumeration(_ scope: String, file: String? = nil) -> Self {
        .init(file: file, type: .enumeration, scope: scope)
    }
}

@inlinable public func hereFunctionSite(
    _ scope: String = #function,
    file: String = #fileID
) -> InvocationCallSite {
    .function(scope, file: file)
}

@inlinable public func hereStructureSite(
    _ scope: String,
    file: String = #fileID
) -> InvocationCallSite {
    .structure(scope, file: file)
}
