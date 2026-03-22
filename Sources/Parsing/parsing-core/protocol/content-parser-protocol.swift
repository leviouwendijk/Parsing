import Foundation

public protocol ContentParser<Output>: TokenParser where Output: Sendable {}

public typealias AnyContentParser<Output: Sendable> = AnyTokenParser<Output>
