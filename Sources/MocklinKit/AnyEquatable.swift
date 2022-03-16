struct AnyEquatable: Equatable {
    let value: Any
    let equals: (Any) -> Bool

    init<T: Equatable>(_ value: T) {
        self.value = value
        self.equals = { other in
            if let other = other as? T {
                return value == other
            }

            return false
        }
    }

    static func == (lhs: AnyEquatable, rhs: AnyEquatable) -> Bool {
        return lhs.equals(rhs.value)
    }
}

extension AnyEquatable: RawMatchable {
    public func matches(_ other: Any) -> Bool {
        return equals(other)
    }
}
