import Foundation

public enum ParseResult<T: Sendable> {
    case success(T, Cursor)
    case failure(Diagnostic)
}

extension ParseResult: Sendable {}

public struct AnyParser<Output: Sendable>: Parser, Sendable {
    private let _parse: @Sendable (Cursor) -> ParseResult<Output>

    public init<P: Parser>(_ p: P) where P.Output == Output {
        self._parse = { c in p.parse(c) }
    }

    public init(_ parse: @Sendable @escaping (Cursor) -> ParseResult<Output>) {
        self._parse = parse
    }

    public func parse(_ c: Cursor) -> ParseResult<Output> { _parse(c) }
}

public protocol Parser<Output>: Sendable {
    associatedtype Output: Sendable
    func parse(_ cursor: Cursor) -> ParseResult<Output>
}

public extension Parser {
    @inlinable
    func map<U>(_ f: @Sendable @escaping (Output) -> U) -> AnyParser<U> {
        AnyParser<U> { c in
            switch self.parse(c) {
            case .success(let o, let next): return .success(f(o), next)
            case .failure(let d):           return .failure(d)
            }
        }
    }

    /// Try `self`; if it fails, try `other`. Type-erased so `other` may be existential.
    // @inlinable
    // func orElse(_ other: any Parser<Output>) -> AnyParser<Output> {
    //     let a = AnyParser(self)
    //     let b = AnyParser(other)
    //     return AnyParser<Output> { c in
    //         switch a.parse(c) {
    //         case .success:             return a.parse(c)
    //         case .failure:             return b.parse(c)
    //         }
    //     }
    // }

    @inlinable
    func orElse(_ other: any Parser<Output>) -> AnyParser<Output> {
        let a = AnyParser(self), b = AnyParser(other)
        return AnyParser<Output> { c in
            let first = a.parse(c)
            switch first {
            case .success: return first
            case .failure: return b.parse(c)
            }
        }
    }

    @inlinable
    func optional() -> AnyParser<Output?> {
        AnyParser<Output?> { c in
            switch self.parse(c) {
            case .success(let o, let next): return .success(o, next)
            case .failure:                  return .success(nil, c)
            }
        }
    }

    @inlinable
    func many(min: Int = 0) -> AnyParser<[Output]> {
        AnyParser<[Output]> { c in
            var cur = c
            var acc: [Output] = []
            while true {
                switch self.parse(cur) {
                case .success(let o, let next): acc.append(o); cur = next
                case .failure:
                    return acc.count >= min
                    ? .success(acc, cur)
                    : .failure(Diagnostic("expected at least \(min) occurrence(s)"))
                }
            }
        }
    }

    @inlinable
    func between<L, R>(
        _ left: any Parser<L>,
        _ right: any Parser<R>
    ) -> AnyParser<Output>
    where L: Sendable, R: Sendable
    {
        let l = AnyParser(left)
        let m = AnyParser(self)
        let r = AnyParser(right)
        return AnyParser<Output> { c in
            switch l.parse(c) {
            case .failure(let d): return .failure(d)
            case .success(_, let c1):
                switch m.parse(c1) {
                case .failure(let d): return .failure(d)
                case .success(let o, let c2):
                    switch r.parse(c2) {
                    case .failure(let d): return .failure(d)
                    case .success(_, let c3): return .success(o, c3)
                    }
                }
            }
        }
    }

    @inlinable
    func withBacktracking() -> AnyParser<Output> {
        AnyParser<Output> { c in
            let mark = c.index
            switch self.parse(c) {
            case .success(let o, let next): return .success(o, next)
            case .failure(let d):
                var restore = c
                restore.restore(mark)
                return .failure(Diagnostic(d.message, severity: d.severity, range: d.range))
            }
        }
    }
}

// You can keep these generic building blocks if you still want them elsewhere:

public struct Map<P: Parser, U: Sendable>: Parser, Sendable {
    public typealias Output = U
    public let p: P
    public let f: @Sendable (P.Output) -> U
    public init(_ p: P, _ f: @Sendable @escaping (P.Output) -> U) { self.p = p; self.f = f }
    public func parse(_ c: Cursor) -> ParseResult<U> {
        switch p.parse(c) {
        case .success(let out, let next): return .success(f(out), next)
        case .failure(let d):             return .failure(d)
        }
    }
}

public struct OptionalP<P: Parser>: Parser {
    public typealias Output = P.Output?
    public let p: P
    public init(_ p: P) { self.p = p }
    public func parse(_ c: Cursor) -> ParseResult<Output> {
        switch p.parse(c) {
        case .success(let out, let next): return .success(out, next)
        case .failure:                    return .success(nil, c)
        }
    }
}

public struct Many<P: Parser>: Parser {
    public typealias Output = [P.Output]
    public let p: P
    public let min: Int
    public init(_ p: P, min: Int) { self.p = p; self.min = min }
    public func parse(_ c: Cursor) -> ParseResult<[P.Output]> {
        var cur = c
        var acc: [P.Output] = []
        while true {
            switch p.parse(cur) {
            case .success(let out, let next): acc.append(out); cur = next
            case .failure:
                return acc.count >= min
                ? .success(acc, cur)
                : .failure(Diagnostic("expected at least \(min) occurrence(s)"))
            }
        }
    }
}
