import SwiftyJSON

struct JSON0Transformer: OperationalTransformer {
    func apply(_ operations: [JSON], to json: JSON) throws -> JSON {
        var json = json
        for operation in operations {
            guard let path = operation[OperationKey.path].array?.map({ $0.stringValue }), !path.isEmpty else {
                throw OperationalTransformError.pathDoesNotExist
            }

            opNumberAdd: if let numberAdd = operation[OperationKey.numberAdd].int, let currentValue = json[path].int {
                let newValue = currentValue + numberAdd
                json[path].int = newValue
            }
            opObjectDelete: if operation[OperationKey.objectDelete].exists() {
                var parentPath = path
                guard let key = parentPath.popLast() else {
                    break opObjectDelete
                }
                if parentPath.isEmpty {
                    json.dictionaryObject?.removeValue(forKey: key)
                } else {
                    json[parentPath].dictionaryObject?.removeValue(forKey: key)
                }
            }
            opObjectInsert: if operation[OperationKey.objectInsert].exists() {
                let insert = operation[OperationKey.objectInsert]
                json[path] = insert
            }
        }
        return json
    }
}

extension ShareDocument {
    public func addNumber(_ amount: Int, at path: JSONSubscriptType...) throws {
        let operationJSON = JSON([
            OperationKey.path: path,
            OperationKey.numberAdd: amount
        ])
        try apply(operations: [operationJSON])
        send(.update(operations: [operationJSON]))
    }

    public func setObject(_ object: JSON, at path: JSONSubscriptType...) throws {
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
