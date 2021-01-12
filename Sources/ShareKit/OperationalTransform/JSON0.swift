let JSON0Subtypes = [
    OperationalTransformSubtype.TEXT0: TEXT0Transformer.self
]

struct JSON0Transformer: OperationalTransformer {
    static let type = OperationalTransformType.JSON0

    static func apply(_ operations: [AnyCodable], to json: AnyCodable) throws -> AnyCodable {
        var json = json
        for operation in operations {
            let path = operation[OperationKey.path].array ?? []
            let pathSubscript: [AnyCodableSubscriptType] = try path.map { token in
                if let pathKey = token.string {
                    return pathKey
                } else if let pathIndex = token.int {
                    return pathIndex
                } else {
                    throw OperationalTransformError.invalidPath
                }
            }
            guard !pathSubscript.isEmpty else {
                throw OperationalTransformError.invalidPath
            }
            if operation[OperationKey.objectDelete] != .undefined || operation[OperationKey.objectInsert] != .undefined {
                var parentPath = pathSubscript
                guard let lastPath = parentPath.popLast(), case let .member(key) = lastPath.anyCodableKey else {
                    throw OperationalTransformError.invalidPath
                }
                guard case .dictionary(var dictionary) = json[parentPath] else {
                    throw OperationalTransformError.invalidPath
                }
                if operation[OperationKey.objectDelete] != .undefined {
                    guard operation[OperationKey.objectDelete] == json[pathSubscript] else {
                        throw OperationalTransformError.oldDataMismatch
                    }
                    dictionary.removeValue(forKey: key)
                    json[parentPath] = .dictionary(dictionary)
                }
                if operation[OperationKey.objectInsert] != .undefined {
                    guard json[pathSubscript] == .undefined else {
                        throw OperationalTransformError.oldDataMismatch
                    }
                    json[pathSubscript] = operation[OperationKey.objectInsert]
                }
            } else if operation[OperationKey.listInsert] != .undefined || operation[OperationKey.listDelete] != .undefined {
                var parentPath = pathSubscript
                guard let lastKey = parentPath.popLast(), case let .index(index) = lastKey.anyCodableKey else {
                    throw OperationalTransformError.invalidPath
                }
                guard case .array(var array) = json[parentPath] else {
                    throw OperationalTransformError.invalidPath
                }
                if operation[OperationKey.listDelete] != .undefined {
                    guard index >= 0, index < array.count else {
                        throw OperationalTransformError.invalidPath
                    }
                    guard operation[OperationKey.listDelete] == json[pathSubscript] else {
                        throw OperationalTransformError.oldDataMismatch
                    }
                    array.remove(at: index)
                    json[parentPath] = .array(array)
                }
                if operation[OperationKey.listInsert] != .undefined {
                    guard index >= 0, index <= array.count else {
                        throw OperationalTransformError.invalidPath
                    }
                    let newData = operation[OperationKey.listInsert]
                    array.insert(newData, at: index)
                    json[parentPath] = .array(array)
                }
            } else if operation[OperationKey.numberAdd] != .undefined {
                let numberAdd = operation[OperationKey.numberAdd]
                switch numberAdd {
                case .int(let int):
                    guard let currentValue = json[pathSubscript].int else {
                        throw OperationalTransformError.oldDataMismatch
                    }
                    json[pathSubscript] = .int(currentValue + int)
                case .decimal(let decimal):
                    guard let currentValue = json[pathSubscript].decimal else {
                        throw OperationalTransformError.oldDataMismatch
                    }
                    json[pathSubscript] = .decimal(currentValue + decimal)
                default:
                    throw OperationalTransformError.invalidJSONData
                }
            } else if operation[OperationKey.subtype] != .undefined {
                guard let subtypeKey = OperationalTransformSubtype(rawValue: operation[OperationKey.subtype].string ?? ""), let subtypeTransformer = JSON0Subtypes[subtypeKey] else {
                    throw OperationalTransformError.unsupportedSubtype
                }
                let transform = try subtypeTransformer.apply(operation[OperationKey.operation].array ?? [], to: json[pathSubscript])
                json[pathSubscript] = transform
            } else {
                throw OperationalTransformError.unsupportedOperation
            }
        }
        return json
    }

    static func inverse(_ operations: [AnyCodable]) throws -> [AnyCodable] {
        return try operations.reversed().map { operation in
            var newOperation = AnyCodable()
            newOperation[OperationKey.path] = operation[OperationKey.path]
            if operation[OperationKey.objectInsert] != .undefined {
                newOperation[OperationKey.objectDelete] = operation[OperationKey.objectInsert]
            }
            if operation[OperationKey.objectDelete] != .undefined {
                newOperation[OperationKey.objectInsert] = operation[OperationKey.objectDelete]
            }
            if operation[OperationKey.listInsert] != .undefined {
                newOperation[OperationKey.listDelete] = operation[OperationKey.listInsert]
            }
            if operation[OperationKey.listDelete] != .undefined {
                newOperation[OperationKey.listInsert] = operation[OperationKey.listDelete]
            }
            if operation[OperationKey.numberAdd] != .undefined {
                let numberAdd = operation[OperationKey.numberAdd]
                switch numberAdd {
                case .int(let int):
                    newOperation[OperationKey.numberAdd] = .int(-int)
                case .decimal(let decimal):
                    newOperation[OperationKey.numberAdd] = .decimal(-decimal)
                default:
                    throw OperationalTransformError.invalidJSONData
                }
            }
            if operation[OperationKey.subtype] != .undefined {
                guard let subtypeKey = OperationalTransformSubtype(rawValue: operation[OperationKey.subtype].string ?? ""), let subtypeTransformer = JSON0Subtypes[subtypeKey] else {
                    throw OperationalTransformError.unsupportedSubtype
                }
                newOperation[OperationKey.subtype] = operation[OperationKey.subtype]
                let subOperations = try subtypeTransformer.inverse(operation[OperationKey.operation].array ?? [])
                newOperation[OperationKey.operation] = .array(subOperations)
            }
            return newOperation
        }
    }
}
