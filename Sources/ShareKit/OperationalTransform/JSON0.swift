import SwiftyJSON

let JSON0Subtypes = [
    OperationalTransformSubtype.TEXT0: TEXT0Transformer.self
]

struct JSON0Transformer: OperationalTransformer {
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
}

extension ShareDocument {
    public func set(number value: Double, at path: JSONSubscriptType...) throws {
        let currentValue = json[path].doubleValue
        let amount = value - currentValue
        let operationJSON = JSON([
            OperationKey.path: path,
            OperationKey.numberAdd: amount
        ])
        try apply(operations: [operationJSON])
        send(.update(operations: [operationJSON]))
    }

    public func change(amount: Double, at path: JSONSubscriptType...) throws {
        let operationJSON = JSON([
            OperationKey.path: path,
            OperationKey.numberAdd: amount
        ])
        try apply(operations: [operationJSON])
        send(.update(operations: [operationJSON]))
    }

    public func set(object: JSON, at path: JSONSubscriptType...) throws {
        guard json[path] != object else {
            return
        }
        guard let endPath = path.last else {
            throw OperationalTransformError.invalidPath
        }
        var operationJSON = JSON([
            OperationKey.path: path
        ])
        switch endPath.jsonKey {
        case .key:
            operationJSON[OperationKey.objectInsert] = object
            if json[path].exists() {
                operationJSON[OperationKey.objectDelete] = json[path]
            }
        case .index:
            operationJSON[OperationKey.listInsert] = object
            if json[path].exists() {
                operationJSON[OperationKey.listDelete] = json[path]
            }
        }
        try apply(operations: [operationJSON])
        send(.update(operations: [operationJSON]))
    }

    public func set(string value: String, at path: JSONSubscriptType...) throws {
        // TODO throw if document type is not JSON0
        let currentValue = json[path].stringValue
        guard let stringOperation = stringDiff(currentValue, value) else {
            return
        }
        let operationJSON = JSON([
            OperationKey.path: path,
            OperationKey.subtype: OperationalTransformSubtype.TEXT0.rawValue,
            OperationKey.operation: stringOperation
        ])
        try apply(operations: [operationJSON])
        send(.update(operations: [operationJSON]))
    }

    public func removeObject(at path: JSONSubscriptType...) throws {
        guard let endPath = path.last else {
            throw OperationalTransformError.invalidPath
        }
        var operationJSON = JSON([
            OperationKey.path: path
        ])
        switch endPath.jsonKey {
        case .key:
            operationJSON[OperationKey.objectDelete] = json[path]
        case .index:
            operationJSON[OperationKey.listDelete] = json[path]
        }
        try apply(operations: [operationJSON])
        send(.update(operations: [operationJSON]))
    }
}
