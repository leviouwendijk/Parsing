// import Foundation

// public struct SourceIndex: Codable, Sendable, Hashable, CustomStringConvertible {
//     public let offset: Int
//     @inlinable public init(_ offset: Int) { self.offset = offset }
//     public var description: String { "\(offset)" }
// }

import Position

@available(*, deprecated, renamed: "PositionIndex")
public typealias SourceIndex = PositionIndex
