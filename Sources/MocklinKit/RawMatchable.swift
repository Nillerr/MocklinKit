import Foundation

public protocol RawMatchable {
    func matches(_ other: Any) -> Bool
}

extension String: RawMatchable {
    public func matches(_ other: Any) -> Bool {
        guard let other = other as? String else {
            return false
        }

        return self == other
    }
}

extension Int8: RawMatchable {
    public func matches(_ other: Any) -> Bool {
        guard let other = other as? Int8 else {
            return false
        }
        
        return self == other
    }
}

extension Int16: RawMatchable {
    public func matches(_ other: Any) -> Bool {
        guard let other = other as? Int16 else {
            return false
        }
        
        return self == other
    }
}

extension Int32: RawMatchable {
    public func matches(_ other: Any) -> Bool {
        guard let other = other as? Int32 else {
            return false
        }
        
        return self == other
    }
}

extension Int64: RawMatchable {
    public func matches(_ other: Any) -> Bool {
        guard let other = other as? Int64 else {
            return false
        }
        
        return self == other
    }
}

extension UInt8: RawMatchable {
    public func matches(_ other: Any) -> Bool {
        guard let other = other as? UInt8 else {
            return false
        }
        
        return self == other
    }
}

extension UInt16: RawMatchable {
    public func matches(_ other: Any) -> Bool {
        guard let other = other as? UInt16 else {
            return false
        }
        
        return self == other
    }
}

extension UInt32: RawMatchable {
    public func matches(_ other: Any) -> Bool {
        guard let other = other as? UInt32 else {
            return false
        }
        
        return self == other
    }
}

extension UInt64: RawMatchable {
    public func matches(_ other: Any) -> Bool {
        guard let other = other as? UInt64 else {
            return false
        }
        
        return self == other
    }
}

extension Int: RawMatchable {
    public func matches(_ other: Any) -> Bool {
        guard let other = other as? Int else {
            return false
        }
        
        return self == other
    }
}

extension Float: RawMatchable {
    public func matches(_ other: Any) -> Bool {
        guard let other = other as? Float else {
            return false
        }
        
        return self == other
    }
}

extension Double: RawMatchable {
    public func matches(_ other: Any) -> Bool {
        guard let other = other as? Double else {
            return false
        }
        
        return self == other
    }
}

extension NSObject: RawMatchable {
    public func matches(_ other: Any) -> Bool {
        isEqual(other)
    }
}

public func eq<T: Equatable>(_ value: T) -> RawMatchable {
    AnyEquatable(value)
}
