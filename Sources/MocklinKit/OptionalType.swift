protocol OptionalType {
    associatedtype Wrapped

    func map<U>(_ transform: (Wrapped) throws -> U) rethrows -> U?
    func flatMap<U>(_ transform: (Wrapped) throws -> U?) rethrows -> U?

    var wrapped: Wrapped? { get }
}

extension OptionalType {
    func zip<O: OptionalType>(with other: O) -> (Wrapped, O.Wrapped)? {
        flatMap { s in other.map { o in (s, o) } }
    }
}
