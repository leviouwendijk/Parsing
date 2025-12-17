import Foundation

public struct BlockStringOptions: Sendable, Equatable {
    public var trimWhitespace: Bool = false              // trim outer whitespace/newlines
    public var unquoteIfWrapped: Bool = false            // remove one leading/trailing "…"
    public var unescapeCommon: Bool = false              // \n \t \" \\ (simple escapes)
    public var normalizeNewlines: Bool = false           // convert CR/LF/CRLF -> \n

    public init(
        trimWhitespace: Bool = false,
        unquoteIfWrapped: Bool = false,
        unescapeCommon: Bool = false,
        normalizeNewlines: Bool = false
    ) {
        self.trimWhitespace = trimWhitespace
        self.unquoteIfWrapped = unquoteIfWrapped
        self.unescapeCommon = unescapeCommon
        self.normalizeNewlines = normalizeNewlines
    }
}

public struct BlockStringPolicy: Sendable, Equatable {
    public var delimiter: Delimiter = .braces
    public var options: BlockStringOptions = .init()
    public init(delimiter: Delimiter = .braces, options: BlockStringOptions = .init()) {
        self.delimiter = delimiter; self.options = options
    }
}

public struct BlockPolicyTable: Sendable {
    public var predetermined: [[String]: BlockStringPolicy] = [:]
    public var fallback: BlockStringPolicy

    public init(
        predetermined: [[String]: BlockStringPolicy] = [:],
        fallback: BlockStringPolicy
    ) {
        self.predetermined = predetermined
        self.fallback = fallback
    }

    public func policy(for keyword: String) -> BlockStringPolicy {
        for (keys, pol) in predetermined where keys.contains(keyword) { return pol }
        return fallback
    }
}
