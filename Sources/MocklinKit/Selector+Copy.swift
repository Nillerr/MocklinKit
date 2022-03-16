import Foundation

extension Selector {
    internal func copy() -> Selector {
        NSSelectorFromString(NSStringFromSelector(self))
    }
}
