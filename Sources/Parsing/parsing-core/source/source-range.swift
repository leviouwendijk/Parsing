// import Foundation

// public struct SourceRange: Codable, Sendable, Hashable {
//     public let start: SourceIndex
//     public let end:   SourceIndex

//     @inlinable public init(_ s: Int, _ e: Int) {
//         self.start = .init(s)
//         self.end   = .init(e)
//     }
// }
import Position

@available(*, deprecated, renamed: "PositionRange")
public typealias SourceRange = PositionRange
