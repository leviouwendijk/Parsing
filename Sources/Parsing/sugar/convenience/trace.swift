import Foundation

public extension TokenParser {
    @inlinable
    func trace(_ label: @autoclosure @escaping @Sendable () -> String) -> AnyTokenParser<Output> {
        let base = AnyTokenParser(self)
        return AnyTokenParser<Output> { c in
            let l = label()
            let before = c.index
            let res = base.parse(c)
            switch res {
            case .success(_, let next):
                fputs("[trace:\(l)] success \(before)->\(next.index)\n", stderr)
            case .failure:
                fputs("[trace:\(l)] failure at \(before)\n", stderr)
            }
            return res
        }
    }

    // @inlinable
    // func trace(_ label: @autoclosure @escaping @Sendable () -> String) -> AnyTokenParser<Output> {
    //     let a = AnyTokenParser(self)
    //     return AnyTokenParser<Output> { c in
    //         #if DEBUG
    //         let l = label()
    //         let before = c.index
    //         let res = a.parse(c)
    //         switch res {
    //         case .success(_, let next):
    //             fputs("[trace:\(l)] success \(before)->\(next.index)\n", stderr)
    //         case .failure:
    //             fputs("[trace:\(l)] failure at \(before)\n", stderr)
    //         }
    //         return res
    //         #else
    //         return a.parse(c)
    //         #endif
    //     }
    // }
}
