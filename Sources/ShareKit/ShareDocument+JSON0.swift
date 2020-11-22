import SwiftyJSON

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
        // TODO throw is document is in invalid or delete state
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
