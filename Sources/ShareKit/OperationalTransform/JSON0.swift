import SwiftyJSON

let JSON0Subtypes = [
    OperationalTransformSubtype.TEXT0: TEXT0Transformer.self
]

struct JSON0Transformer: OperationalTransformer {
    static func apply(_ operations: [JSON], to json: JSON) throws -> JSON {
        var json = json
        for operation in operations {
            guard let path = operation[OperationKey.path].array?.map({ $0.stringValue }), !path.isEmpty else {
                throw OperationalTransformError.emptyPath
            }
            if operation[OperationKey.objectDelete].exists() || operation[OperationKey.objectInsert].exists() {
                if operation[OperationKey.objectDelete].exists() {
                    guard operation[OperationKey.objectDelete] == json[path] else {
                        throw OperationalTransformError.oldDataMismatch
                    }
                    var parentPath = path
                    guard let key = parentPath.popLast() else {
                        throw OperationalTransformError.emptyPath
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
            throw OperationalTransformError.emptyPath
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
            throw OperationalTransformError.emptyPath
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
