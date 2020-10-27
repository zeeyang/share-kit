import SwiftyJSON

struct JSON0Transformer: OperationalTransformer {
    func transform(_ operations: [JSON], to json: JSON) throws -> JSON {
        var json = json
        for operation in operations {
            func getJSON(_ key: OperationKey) -> JSON {
                return operation[key.rawValue]
            }
            guard let path = getJSON(.path).array?.map({ $0.stringValue }), !path.isEmpty else {
                throw OperationalTransformError.pathDoesNotExist
            }

            opNumberAdd: if let numberAdd = getJSON(.numberAdd).int, let currentValue = json[path].int {
                let newValue = currentValue + numberAdd
                json[path].int = newValue
            }
            opObjectDelete: if getJSON(.objectDelete).exists() {
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
            opObjectInsert: if getJSON(.objectInsert).exists() {
                let insert = getJSON(.objectInsert)
                json[path] = insert
            }
        }
        return json
    }
}
