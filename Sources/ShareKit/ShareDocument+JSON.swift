import SwiftyJSON

extension ShareDocument: MutableJSON {
    public func addNumber(_ amount: Int, at path: JSONSubscriptType...) throws {
        let dict = [
            makeOp(path, at: .path),
            makeOp(amount, at: .numberAdd)
        ]
        let operation = Dictionary(uniqueKeysWithValues: dict)
        let json = [JSON(operation)]
        try apply(operations: json)
        send(.update(operations: json))
    }

    public func setObject(_ object: JSON, at path: JSONSubscriptType...) throws {
        var dict = [makeOp(path, at: .path)]
        guard json[path] != object else { return } // TODO throw?
        switch path.last?.jsonKey {
        case .key?:
            dict.append(makeOp(object, at: .objectInsert))
            if json[path].exists() {
                dict.append(makeOp(json[path].rawValue, at: .objectDelete))
            }
        case .index?:
            dict.append(makeOp(object, at: .listInsert))
            if json[path].exists() {
                dict.append(makeOp(json[path].rawValue, at: .listDelete))
            }
        case nil:
            break
        }
        let operation = Dictionary(uniqueKeysWithValues: dict)
        let json = [JSON(operation)]
        try apply(operations: json)
        send(.update(operations: json))
    }

    public func removeObject(at path: JSONSubscriptType...) throws {
        var dict = [makeOp(path, at: .path)]
        let object = json[path]
        switch path.last?.jsonKey {
        case .key?:
            dict.append(makeOp(object, at: .objectDelete))
        case .index?:
            dict.append(makeOp(object, at: .listDelete))
        case nil:
            break
        }
        let operation = Dictionary(uniqueKeysWithValues: dict)
        let json = [JSON(operation)]
        try apply(operations: json)
        send(.update(operations: json))
    }
}

private func makeOp(_ value: Any, at key: OperationKey) -> (String, Any) {
    return (key.rawValue, value)
}
