extension OptionalType where Wrapped: RawMatchable {
    func matches(_ other: Any) -> Bool {
        if let other = other as? Self {
            if let s = wrapped, let o = other.wrapped {
                return s.matches(o)
            }

            return wrapped == nil && other.wrapped == nil
        } else {
            return false
        }
    }
}
