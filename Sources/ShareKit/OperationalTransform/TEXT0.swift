import SwiftyJSON

struct TEXT0Transformer: OperationalTransformer {
    static func apply(_ operations: [JSON], to json: JSON) throws -> JSON {
        var characters = Array(json.stringValue)
        for operation in operations {
            guard let startIndex = operation[OperationKey.path].int else {
                continue
            }
            let prefix = characters[0..<startIndex]
            var endIndex = startIndex
            if let deletion = operation[OperationKey.delete].string {
                endIndex += deletion.count
            }
            let suffix = characters[endIndex...]
            if let insertion = operation[OperationKey.insert].string {
                characters = prefix + Array(insertion) + suffix
            } else {
                characters = Array(prefix + suffix)
            }
        }
        return JSON(String(characters))
    }
}

func stringDiff(_ source: String, _ target: String) -> JSON? {
    switch Array(source).diff(Array(target)) {
    case .equal:
        return nil
    case .insert(let start, let chars):
        return ["p": start, "i": String(chars)]
    case .delete(let start, let chars):
        return ["p": start, "d": String(chars)]
    case .replace(let start, let delete, let insert):
        return ["p": start, "d": String(delete), "i": String(insert)]
    }
}
