import SwiftyJSON

let JSON0Subtypes = [
    OperationalTransformSubtype.TEXT0: TEXT0Transformer.self
]

struct JSON0Transformer: OperationalTransformer {
    static let type = OperationalTransformType.JSON0

    static func apply(_ operations: [JSON], to json: JSON) throws -> JSON {
        var json = json
        for operation in operations {
            let path: [JSONSubscriptType] = try operation[OperationKey.path].arrayValue.map { token in
                if let pathKey = token.string {
                    return pathKey
                } else if let pathIndex = token.int {
                    return pathIndex
                } else {
                    throw OperationalTransformError.invalidPath
                }
            }
            guard !path.isEmpty else {
                throw OperationalTransformError.invalidPath
            }
            if operation[OperationKey.objectDelete].exists() || operation[OperationKey.objectInsert].exists() {
                if operation[OperationKey.objectDelete].exists() {
                    guard operation[OperationKey.objectDelete] == json[path] else {
                        throw OperationalTransformError.oldDataMismatch
                    }
                    var parentPath = path
                    guard let lastPath = parentPath.popLast(), case let .key(key) = lastPath.jsonKey else {
                        throw OperationalTransformError.invalidPath
                    }
                    if parentPath.isEmpty {
                        json.dictionaryObject?.removeValue(forKey: key)
                    } else {
                        json[parentPath].dictionaryObject?.removeValue(forKey: key)
                    }
                }
                if operation[OperationKey.objectInsert].exists() {
                    guard !json[path].exists() else {
                        throw OperationalTransformError.oldDataMismatch
                    }
                    json[path] = operation[OperationKey.objectInsert]
                }
            } else if operation[OperationKey.listInsert].exists() || operation[OperationKey.listDelete].exists() {
                var parentPath = path
                guard let lastKey = parentPath.popLast(), case let .index(index) = lastKey.jsonKey else {
                    throw OperationalTransformError.invalidPath
                }
                guard let arrayCount = json[parentPath].arrayObject?.count else {
                    throw OperationalTransformError.invalidJSONData
                }
                if operation[OperationKey.listDelete].exists() {
                    guard index >= 0, index < arrayCount else {
                        throw OperationalTransformError.invalidPath
                    }
                    guard operation[OperationKey.listDelete] == json[path] else {
                        throw OperationalTransformError.oldDataMismatch
                    }
                    json[parentPath].arrayObject?.remove(at: index)
                }
                if operation[OperationKey.listInsert].exists() {
                    guard index >= 0, index <= arrayCount else {
                        throw OperationalTransformError.invalidPath
                    }
                    let newData = operation[OperationKey.listInsert]
                    json[parentPath].arrayObject?.insert(newData, at: index)
                }
            } else if let numberAdd = operation[OperationKey.numberAdd].double {
                guard let currentValue = json[path].double else {
                    throw OperationalTransformError.oldDataMismatch
                }
                json[path].double = currentValue + numberAdd
            } else if operation[OperationKey.subtype].exists() {
                guard let subtypeKey = OperationalTransformSubtype(rawValue: operation[OperationKey.subtype].stringValue), let subtypeTransformer = JSON0Subtypes[subtypeKey] else {
                    throw OperationalTransformError.unsupportedSubtype
                }
                json[path] = try subtypeTransformer.apply(operation[OperationKey.operation].arrayValue, to: json[path])
            } else {
                throw OperationalTransformError.unsupportedOperation
            }
        }
        return json
    }

    static func append(_ operation: JSON, to previousOperations: [JSON]) -> [JSON] {
        return previousOperations + [operation]
    }

    static func inverse(_ operations: [JSON]) throws -> [JSON] {
        return try operations.reversed().map { operation in
            var newOperation = JSON()
            newOperation[OperationKey.path] = operation[OperationKey.path]
            if operation[OperationKey.objectInsert].exists() {
                newOperation[OperationKey.objectDelete] = operation[OperationKey.objectInsert]
            }
            if operation[OperationKey.objectDelete].exists() {
                newOperation[OperationKey.objectInsert] = operation[OperationKey.objectDelete]
            }
            if operation[OperationKey.listInsert].exists() {
                newOperation[OperationKey.listDelete] = operation[OperationKey.listInsert]
            }
            if operation[OperationKey.listDelete].exists() {
                newOperation[OperationKey.listInsert] = operation[OperationKey.listDelete]
            }
            if operation[OperationKey.numberAdd].exists() {
                newOperation[OperationKey.numberAdd] = JSON(-operation[OperationKey.numberAdd].doubleValue)
            }
            if operation[OperationKey.subtype].exists() {
                guard let subtypeKey = OperationalTransformSubtype(rawValue: operation[OperationKey.subtype].stringValue), let subtypeTransformer = JSON0Subtypes[subtypeKey] else {
                    throw OperationalTransformError.unsupportedSubtype
                }
                newOperation[OperationKey.subtype] = operation[OperationKey.subtype]
                newOperation[OperationKey.operation].arrayObject = try subtypeTransformer.inverse(operation[OperationKey.operation].arrayValue)
            }
            return newOperation
        }
    }
}
