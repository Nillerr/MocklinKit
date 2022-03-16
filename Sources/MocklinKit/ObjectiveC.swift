import Foundation

internal func protocol_getMethodDescriptionList(_ aProtocol: Protocol) -> [MethodDescription] {
    var count: UInt32 = 0
    if let cMethodList = protocol_copyMethodDescriptionList(aProtocol, true, true, &count) {
        defer { free(cMethodList) }

        return (0 ..< count)
            .map { i in cMethodList[Int(i)] }
            .compactMap { cMethod in cMethod.name.zip(with: cMethod.types) }
            .map { name, types in
                MethodDescription(name: name.copy(), types: String(cString: types))
            }
    }

    return []
}

internal func imp_implementationWithBlock(for desc: MethodDescription, block: @escaping (AnyObject, [Any]) -> Any) -> IMP {
    let params = desc.types.split(separator: ":").last!
    let decimals = CharacterSet.decimalDigits
    let filtered = String(params.unicodeScalars.filter { !decimals.contains($0) })

    switch filtered.count {
    case 0:
        let block: @convention(block) (AnyObject) -> Any = { target in
            block(target, [])
        }

        return imp_implementationWithBlock(block)
    case 1:
        let block: @convention(block) (AnyObject, Any) -> Any = { target, arg1 in
            block(target, [arg1])
        }

        return imp_implementationWithBlock(block)
    case 2:
        let block: @convention(block) (AnyObject, Any, Any) -> Any = { target, arg1, arg2 in
            block(target, [arg1, arg2])
        }

        return imp_implementationWithBlock(block)
    case 3:
        let block: @convention(block) (AnyObject, Any, Any, Any) -> Any = { target, arg1, arg2, arg3 in
            block(target, [arg1, arg2, arg3])
        }

        return imp_implementationWithBlock(block)
    case 4:
        let block: @convention(block) (AnyObject, Any, Any, Any, Any) -> Any = { target, arg1, arg2, arg3, arg4 in
            block(target, [arg1, arg2, arg3, arg4])
        }

        return imp_implementationWithBlock(block)
    case 5:
        let block: @convention(block) (AnyObject, Any, Any, Any, Any, Any) -> Any = { target, arg1, arg2, arg3, arg4, arg5 in
            block(target, [arg1, arg2, arg3, arg4, arg5])
        }

        return imp_implementationWithBlock(block)
    default:
        let block: @convention(block) (AnyObject) -> Any = { target in
            block(target, [])
        }

        return imp_implementationWithBlock(block)
    }
}
