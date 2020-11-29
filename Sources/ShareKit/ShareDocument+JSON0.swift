import SwiftyJSON

extension ShareDocument {
    public func set<T>(number value: T, at path: JSONSubscriptType...) throws where T: AdditiveArithmetic {
        try assertJSON0()
        guard let currentValue = json[path].rawValue as? T else {
            throw ShareDocumentError.decodeDocumentData
        }
        let amount = value - currentValue
        let operationJSON = JSON([
            OperationKey.path: path,
            OperationKey.numberAdd: amount
        ])
        try apply(operations: [operationJSON])
        send(.update(operations: [operationJSON]))
    }

    public func change<T>(amount: T, at path: JSONSubscriptType...) throws where T: AdditiveArithmetic {
        try assertJSON0()
        let operationJSON = JSON([
            OperationKey.path: path,
            OperationKey.numberAdd: amount
        ])
        try apply(operations: [operationJSON])
        send(.update(operations: [operationJSON]))
    }

    public func set(object: JSON, at path: JSONSubscriptType...) throws {
        try assertJSON0()
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
        try assertJSON0()
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
        try assertJSON0()
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

    private func assertJSON0() throws {
        guard transformer.type == .JSON0 else {
            throw ShareDocumentError.transformType
        }
        guard state != .deleted else {
            throw ShareDocumentError.documentState
        }
    }
}
