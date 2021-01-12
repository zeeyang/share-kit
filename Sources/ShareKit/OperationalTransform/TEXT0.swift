struct TEXT0Transformer: OperationalTransformer {
    static let type = OperationalTransformType.TEXT0

    static func apply(_ operations: [AnyCodable], to data: AnyCodable) throws -> AnyCodable {
        var characters = Array(data.string ?? "")
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
        return .string(String(characters))
    }

    static func inverse(_ operations: [AnyCodable]) throws -> [AnyCodable] {
        return operations.reversed().map { operation in
            var newOperation = operation
            newOperation[OperationKey.path] = operation[OperationKey.path]
            if operation[OperationKey.insert] != .undefined {
                newOperation[OperationKey.delete] = operation[OperationKey.insert]
            }
            if operation[OperationKey.delete] != .undefined {
                newOperation[OperationKey.insert] = operation[OperationKey.delete]
            }
            return newOperation
        }
    }
}

func stringDiff(_ source: String, _ target: String) -> AnyCodable {
    switch Array(source).diff(Array(target)) {
    case .equal:
        return []
    case .insert(let start, let chars):
        return [["p": start, "i": String(chars)]]
    case .delete(let start, let chars):
        return [["p": start, "d": String(chars)]]
    case .replace(let start, let delete, let insert):
        return [["p": start, "d": String(delete)], ["p": start, "i": String(insert)]]
    }
}
