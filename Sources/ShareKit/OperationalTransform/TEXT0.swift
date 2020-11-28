import SwiftyJSON

struct TEXT0Transformer: OperationalTransformer {
    static let type = OperationalTransformType.TEXT0

    static func apply(_ operations: [JSON], to json: JSON) throws -> JSON {
        var characters = Array(json.stringValue)
        for operation in operations {
            guard let startIndex = operation[OperationKey.path].int else {
                throw OperationalTransformError.invalidPath
            }
            guard startIndex <= characters.count else {
                throw OperationalTransformError.indexOutOfRange
            }
            let prefix = characters[0..<startIndex]
            var endIndex = startIndex
            if let deletion = operation[OperationKey.delete].string {
                endIndex += deletion.count
                guard endIndex <= characters.count else {
                    throw OperationalTransformError.indexOutOfRange
                }
                guard deletion == String(characters[startIndex..<endIndex]) else {
                    throw OperationalTransformError.oldDataMismatch
                }
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

    static func append(_ operation: JSON, to previousOperations: [JSON]) -> [JSON] {
        return previousOperations + [operation]
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
