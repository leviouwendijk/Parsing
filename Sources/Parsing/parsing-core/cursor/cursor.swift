import Foundation

public struct Cursor: Sendable {
    public let input: String
    public private(set) var index: String.Index

    public init(_ s: String) { self.input = s; self.index = s.startIndex }

    public var isEOF: Bool { index >= input.endIndex }
    public var offset: Int { input.distance(from: input.startIndex, to: index) }

    public func peek() -> Character? {
        isEOF ? nil : input[index]
    }

    public mutating func advance() {
        guard !isEOF else { return }
        index = input.index(after: index)
    }

    public mutating func advance(while predicate: (Character)->Bool) {
        while let c = peek(), predicate(c) { advance() }
    }

    public mutating func skipWhitespace() {
        advance { $0.isWhitespace || $0.isNewline }
    }

    public func mark() -> String.Index { index }
    public mutating func restore(_ m: String.Index) { index = m }

    public mutating func slice(from start: String.Index) -> String {
        String(input[start..<index])
    }

    public func range(from start: String.Index) -> SourceRange {
        SourceRange(input.distance(from: input.startIndex, to: start), offset)
    }
}
