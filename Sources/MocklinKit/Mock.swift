import Foundation
import XCTest

public class Mock<Target> {
    private let type: Target.Type
    private let aClass: AnyClass

    public private(set) var target: Target!

    private var stubs: [Stub] = []
    public private(set) var invocations: [Invocation] = []
    
    public init(_ type: Target.Type, class superclass: AnyClass, file: StaticString = #file, line: UInt = #line) {
        self.type = Target.self
        
        self.aClass = objc_allocateClassPair(superclass, "Mocklin<\(Target.self)>_\(UUID().uuidString)", 0)!
        
        var count: UInt32 = 0
        if let cMethodList = class_copyMethodList(aClass, &count) {
            defer { free(cMethodList) }
            
            (0 ..< count)
                .map { i in cMethodList[Int(i)] }
                .forEach { cMethod in
                    let methodDesc = method_getDescription(cMethod)[0]
                    if let name = methodDesc.name, let types = methodDesc.types.map({ String(cString: $0) }) {
                        let desc = MethodDescription(name: name, types: types)
                        let imp = stubImp(for: desc, file: file, line: line)
                        class_addMethod(aClass, name, imp, types)
                    }
                }
        }
        
        objc_registerClassPair(aClass)

        self.target = (aClass.alloc() as! Target)
    }

    public init(_ type: Target.Type, protocol aProtocol: Protocol, file: StaticString = #file, line: UInt = #line) {
        self.type = type

        self.aClass = objc_allocateClassPair(NSObject.self, "Mocklin<\(String(describing: type))>_\(UUID().uuidString)", 0)!
        class_addProtocol(aClass, aProtocol)

        protocol_getMethodDescriptionList(aProtocol)
            .forEach { methodDesc in
                let imp = stubImp(for: methodDesc, file: file, line: line)
                class_addMethod(aClass, methodDesc.name, imp, methodDesc.types)
            }

        objc_registerClassPair(aClass)

        self.target = (aClass.alloc() as! Target)
    }
    
    private func stubImp(for methodDesc: MethodDescription, file: StaticString = #file, line: UInt = #line) -> IMP {
        let name = String(describing: type)
        
        return imp_implementationWithBlock(for: methodDesc) { [weak self] _, args in
            guard let `self` = self else {
                fatalError("The mock of type \(name) created in \(file):\(line) was deallocated.")
            }

            let stubOrNil = self.stubs
                .filter { stub in stub.selector == methodDesc.name }
                .filter { stub in stub.matches(args) }
                .first

            guard let stub = stubOrNil else {
                fatalError("A stub for the selector \(methodDesc.name) on the \(name) mock created in \(file):\(line) was not found.")
            }

            return stub.invoke(withArguments: args)
        }
    }

    deinit {
        target = nil

        objc_disposeClassPair(aClass)
    }
    
    private func invocations(matching verification: Verification) -> [Invocation] {
        return invocations
            .filter { $0.selector == verification.selector }
            .filter { $0.matches(matchers: verification.matchers) }
    }

    private func addStub(selector: Selector, matchers: [RawMatchable]?, implementation: @escaping ([Any]) -> Any) {
        let stub = Stub(mock: self, selector: selector, matchers: matchers, implementation: implementation)
        stubs = [stub] + stubs
    }
    
    public func given(_ aSelector: (Target) -> Selector) -> GivenBuilder {
        GivenBuilder(selector: aSelector(target), mock: self, matchers: nil)
    }

    public func verify(_ aSelector: (Target) -> Selector) -> VerifyBuilder {
        VerifyBuilder(selector: aSelector(target), mock: self, matchers: nil)
    }

    public func verify(file: StaticString = #file, line: UInt = #line) {
        let unverified = invocations.filter { !$0.isVerified }
        if !unverified.isEmpty {
            XCTFail("\(unverified.count) invocations were unverified: \(unverified)", file: file, line: line)
        }
    }

    private func verify(_ verification: Verification, file: StaticString = #file, line: UInt = #line) {
        let matches = invocations(matching: verification)
            .filter { !$0.isVerified }

        if let exactly = verification.exactly {
            if matches.count == exactly {
                matches.forEach { $0.markVerified() }
            } else {
                XCTFail("Expected the selector \(verification.selector) on mock of type \(type) to have been invoked exactly \(exactly) times. Was invoked \(matches.count) times.", file: file, line: line)
            }
        } else {
            if matches.count >= verification.atLeast && matches.count <= verification.atMost {
                matches.forEach { $0.markVerified() }
            } else {
                XCTFail("Expected the selector \(verification.selector) on mock of type \(type) to have been invoked at least \(verification.atLeast) and at most \(verification.atMost) times. Was invoked \(matches.count) times.", file: file, line: line)
            }
        }
    }
    
    public struct SignedGivenBuilder<B, R> {
        public let selector: Selector
        public let mock: Mock<Target>
        public let matchers: [RawMatchable]?
        public let implementation: (B) -> ([Any]) -> R

        public func withArguments(_ matchers: RawMatchable...) -> SignedGivenBuilder<B, R> {
            SignedGivenBuilder(selector: selector, mock: mock, matchers: matchers, implementation: implementation)
        }

        public func will(_ block: B) {
            mock.addStub(selector: selector, matchers: matchers, implementation: implementation(block))
        }

        public func willReturn(_ value: R) {
            mock.addStub(selector: selector, matchers: matchers) { _ in value }
        }
    }

    public struct GivenBuilder {
        public let selector: Selector
        public let mock: Mock<Target>
        public let matchers: [RawMatchable]?

        public func withArguments(_ matchers: RawMatchable...) -> GivenBuilder {
            GivenBuilder(selector: selector, mock: mock, matchers: matchers)
        }

        public func withSignature<R>(_ signature: (Target) -> R) -> SignedGivenBuilder<() -> R, R> {
            withSignatureBuilder { block in
                { args in block() }
            }
        }

        public func withSignature<T1, R>(_ signature: (Target) -> (T1) -> R) -> SignedGivenBuilder<(T1) -> R, R> {
            withSignatureBuilder { block in
                { args in block(args[0] as! T1) }
            }
        }

        public func withSignature<T1, T2, R>(_ signature: (Target) -> (T1, T2) -> R) -> SignedGivenBuilder<(T1, T2) -> R, R> {
            withSignatureBuilder { block in
                { args in block(args[0] as! T1, args[1] as! T2) }
            }
        }

        public func withSignature<T1, T2, T3, R>(_ signature: (Target) -> (T1, T2, T3) -> R) -> SignedGivenBuilder<(T1, T2, T3) -> R, R> {
            withSignatureBuilder { block in
                { args in block(args[0] as! T1, args[1] as! T2, args[2] as! T3) }
            }
        }

        public func withSignature<T1, T2, T3, T4, R>(_ signature: (Target) -> (T1, T2, T3, T4) -> R) -> SignedGivenBuilder<(T1, T2, T3, T4) -> R, R> {
            withSignatureBuilder { block in
                { args in block(args[0] as! T1, args[1] as! T2, args[2] as! T3, args[3] as! T4) }
            }
        }

        public func withSignature<T1, T2, T3, T4, T5, R>(_ signature: (Target) -> (T1, T2, T3, T4, T5) -> R) -> SignedGivenBuilder<(T1, T2, T3, T4, T5) -> R, R> {
            withSignatureBuilder { block in
                { args in block(args[0] as! T1, args[1] as! T2, args[2] as! T3, args[3] as! T4, args[4] as! T5) }
            }
        }

        private func withSignatureBuilder<B, R>(_ implementation: @escaping (B) -> ([Any]) -> R) -> SignedGivenBuilder<B, R> {
            SignedGivenBuilder(selector: selector, mock: mock, matchers: matchers, implementation: implementation)
        }

        public func willReturn(_ value: Any) {
            mock.addStub(selector: selector, matchers: matchers) { _ in value }
        }
    }

    public struct SignedVerifyBuilder<B, R> {
        public let selector: Selector
        public let mock: Mock<Target>
        public let matchers: [RawMatchable]?

        public func withArguments(_ matchers: RawMatchable...) -> SignedVerifyBuilder<B, R> {
            SignedVerifyBuilder(selector: selector, mock: mock, matchers: matchers)
        }

        public func wasCalled(exactly: Int, file: StaticString = #file, line: UInt = #line) {
            let verification = Verification(selector: selector, matchers: matchers, exactly: exactly, atLeast: exactly, atMost: exactly)
            mock.verify(verification, file: file, line: line)
        }

        public func wasCalled(atLeast: Int = 1, atMost: Int = .max, file: StaticString = #file, line: UInt = #line) {
            let verification = Verification(selector: selector, matchers: matchers, exactly: nil, atLeast: atLeast, atMost: atMost)
            mock.verify(verification, file: file, line: line)
        }
    }

    public struct VerifyBuilder {
        public let selector: Selector
        public let mock: Mock<Target>
        public let matchers: [RawMatchable]?

        public func withArguments(_ matchers: RawMatchable...) -> VerifyBuilder {
            VerifyBuilder(selector: selector, mock: mock, matchers: matchers)
        }

        public func withSignature<R>(_ signature: (Target) -> R) -> SignedVerifyBuilder<() -> R, R> {
            withSignatureBuilder { block in
                { args in block() }
            }
        }

        public func withSignature<T1, R>(_ signature: (Target) -> (T1) -> R) -> SignedVerifyBuilder<(T1) -> R, R> {
            withSignatureBuilder { block in
                { args in block(args[0] as! T1) }
            }
        }

        public func withSignature<T1, T2, R>(_ signature: (Target) -> (T1, T2) -> R) -> SignedVerifyBuilder<(T1, T2) -> R, R> {
            withSignatureBuilder { block in
                { args in block(args[0] as! T1, args[1] as! T2) }
            }
        }

        public func withSignature<T1, T2, T3, R>(_ signature: (Target) -> (T1, T2, T3) -> R) -> SignedVerifyBuilder<(T1, T2, T3) -> R, R> {
            withSignatureBuilder { block in
                {args in
                    block(
                        args[0] as! T1,
                        args[1] as! T2,
                        args[2] as! T3
                    )
                }
            }
        }

        public func withSignature<T1, T2, T3, T4, R>(_ signature: (Target) -> (T1, T2, T3, T4) -> R) -> SignedVerifyBuilder<(T1, T2, T3, T4) -> R, R> {
            withSignatureBuilder { block in
                { args in block(args[0] as! T1, args[1] as! T2, args[2] as! T3, args[3] as! T4) }
            }
        }

        public func withSignature<T1, T2, T3, T4, T5, R>(_ signature: (Target) -> (T1, T2, T3, T4, T5) -> R) -> SignedVerifyBuilder<(T1, T2, T3, T4, T5) -> R, R> {
            withSignatureBuilder { block in
                { args in block(args[0] as! T1, args[1] as! T2, args[2] as! T3, args[3] as! T4, args[4] as! T5) }
            }
        }

        private func withSignatureBuilder<B, R>(_ implementation: @escaping (B) -> ([Any]) -> R) -> SignedVerifyBuilder<B, R> {
            SignedVerifyBuilder(selector: selector, mock: mock, matchers: matchers)
        }

        public func wasCalled(exactly: Int, file: StaticString = #file, line: UInt = #line) {
            let verification = Verification(selector: selector, matchers: matchers, exactly: exactly, atLeast: exactly, atMost: exactly)
            mock.verify(verification, file: file, line: line)
        }

        public func wasCalled(atLeast: Int = 1, atMost: Int = .max, file: StaticString = #file, line: UInt = #line) {
            let verification = Verification(selector: selector, matchers: matchers, exactly: nil, atLeast: atLeast, atMost: atMost)
            mock.verify(verification, file: file, line: line)
        }
    }
    
    public struct Stub {
        let mock: Mock<Target>
        let selector: Selector
        let matchers: [RawMatchable]?
        let implementation: ([Any]) -> Any

        init(mock: Mock<Target>, selector: Selector, matchers: [RawMatchable]?, implementation: @escaping ([Any]) -> Any) {
            self.mock = mock
            self.selector = selector
            self.matchers = matchers
            self.implementation = implementation
        }

        func matches(_ args: [Any]) -> Bool {
            if let matchers = matchers {
                return zip(matchers, args)
                    .allSatisfy { matcher, arg in matcher.matches(arg) }
            }

            return true
        }

        func invoke(withArguments arguments: [Any]) -> Any {
            mock.invocations.append(Invocation(selector: selector, arguments: arguments))
            return implementation(arguments)
        }
    }

    private struct Verification {
        let selector: Selector
        let matchers: [RawMatchable]?
        let exactly: Int?
        let atLeast: Int
        let atMost: Int
    }

    public class Invocation: CustomStringConvertible {
        public let selector: Selector
        public let arguments: [Any]

        public private(set) var isVerified: Bool = false

        internal init(selector: Selector, arguments: [Any]) {
            self.selector = selector
            self.arguments = arguments
        }

        public func matches(matchers: [RawMatchable]?) -> Bool {
            if let matchers = matchers {
                return zip(matchers, arguments)
                    .allSatisfy { matcher, arg in matcher.matches(arg) }
            }

            return true
        }

        internal func markVerified() {
            isVerified = true
        }

        public var description: String {
            "\(selector)(\(arguments.map({ "\($0)" }).joined(separator: ", ")))"
        }
    }
}
