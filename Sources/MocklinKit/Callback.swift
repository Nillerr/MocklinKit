import Foundation
import XCTest

public class Callback {
    
    private(set) var invocations: [Invocation] = []
    
    func invoke(_ arg1: Any) {
        invocations.append(Invocation(arguments: [arg1]))
    }
    
    func invoke(_ arg1: Any, _ arg2: Any) {
        invocations.append(Invocation(arguments: [arg1, arg2]))
    }
    
    func invoke(_ arg1: Any, _ arg2: Any, _ arg3: Any) {
        invocations.append(Invocation(arguments: [arg1, arg2, arg3]))
    }
    
    func invoke(_ arg1: Any, _ arg2: Any, _ arg3: Any, _ arg4: Any) {
        invocations.append(Invocation(arguments: [arg1, arg2, arg3, arg4]))
    }
    
    func invoke(_ arg1: Any, _ arg2: Any, _ arg3: Any, _ arg4: Any, _ arg5: Any) {
        invocations.append(Invocation(arguments: [arg1, arg2, arg3, arg4, arg5]))
    }
    
    func verify(file: StaticString = #file, line: UInt = #line) {
        let unverified = invocations.filter { !$0.isVerified }
        if !unverified.isEmpty {
            XCTFail("\(unverified.count) invocations were unverified: \(unverified)", file: file, line: line)
        }
    }
    
    func verify(file: StaticString = #file, line: UInt = #line, exactly: Int) {
        verify(file: file, line: line, exactly: exactly, atLeast: 0, atMost: .max, arguments: nil)
    }
    
    func verify(file: StaticString = #file, line: UInt = #line, exactly: Int, arguments matchers: RawMatchable...) {
        verify(file: file, line: line, exactly: exactly, atLeast: 0, atMost: .max, arguments: matchers)
    }
    
    private func verify(file: StaticString = #file, line: UInt = #line, exactly: Int?, atLeast: Int, atMost: Int, arguments matchers: [RawMatchable]?) {
        let matches = invocations
            .filter { $0.matches(matchers: matchers) }
            .filter { !$0.isVerified }
        
        if let exactly = exactly {
            if matches.count == exactly {
                matches.forEach { $0.markVerified() }
            } else {
                XCTFail("Expected the callback to have been invoked exactly \(exactly) times. Was invoked \(matches.count) times.", file: file, line: line)
            }
        } else {
            if matches.count >= atLeast && matches.count <= atMost {
                matches.forEach { $0.markVerified() }
            } else {
                XCTFail("Expected the callback to have been invoked at least \(atLeast) and at most \(atMost) times. Was invoked \(matches.count) times.", file: file, line: line)
            }
        }
    }
    
    public class Invocation {
        public let arguments: [Any]
        
        private(set) var isVerified: Bool = false
        
        init(arguments: [Any]) {
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
    }
}
