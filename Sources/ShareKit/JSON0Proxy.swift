import Foundation

public class Transaction {
    var operations: [AnyCodable] = []
}

@dynamicMemberLookup
public struct JSON0Proxy {
    enum ProxyError: Error {
        case unknownMember
        case noTransaction
        case invalidParent
        case invalidFieldType
    }

    private var path: [AnyCodableSubscriptType]
    private var data: AnyCodable
    private var parent: AnyCodable?
    private var transaction: Transaction

    public init(path: [AnyCodableSubscriptType], data: AnyCodable, parent: AnyCodable? = nil, transaction: Transaction) {
        self.path = path
        self.data = data
        self.parent = parent
        self.transaction = transaction
    }

    public subscript(key: AnyCodableSubscriptType) -> JSON0Proxy {
        let childPath = path + [key]
        return JSON0Proxy(path: childPath, data: data[key], parent: self.data, transaction: transaction)
    }

    public subscript(dynamicMember member: String) -> JSON0Proxy {
        return self[member]
    }

    public func set(_ anyValue: Any) throws {
        let newValue = AnyCodable(anyValue)
        guard self.data != newValue else {
            return
        }
        var operation = [OperationKey.path: AnyCodable(path)]
        switch parent {
        case .array?:
            let arrayOperation = setChildValue(newValue, key: (OperationKey.listInsert, OperationKey.listDelete))
            operation.merge(arrayOperation) { (_, new) in new }
        case .dictionary?:
            let dictionaryOperation = setChildValue(newValue, key: (OperationKey.objectInsert, OperationKey.objectDelete))
            operation.merge(dictionaryOperation) { (_, new) in new }
        default:
            throw ProxyError.invalidParent
        }
        transaction.operations.append(.dictionary(operation))
    }

    private func setChildValue(_ newValue: AnyCodable, key: (insert: String, delete: String)) -> [String: AnyCodable] {
        var operation: [String: AnyCodable] = [:]

        // Remove existing value
        switch self.data {
        case .array, .dictionary, .bool:
            operation[OperationKey.objectDelete] = self.data
        case .int, .decimal, .string:
            if newValue == .null || newValue == .undefined {
                operation[key.delete] = self.data
            }
        case .null, .undefined:
            break
        }

        // Set new value
        switch newValue {
        case .array, .dictionary, .bool, .null:
            operation[key.insert] = newValue
        case .int(let newInt):
            guard case .int(let int) = self.data else {
                operation[key.insert] = newValue
                break
            }
            operation[OperationKey.numberAdd] = .int(newInt - int)
        case .decimal(let newDecimal):
            guard case .decimal(let decimal) = self.data else {
                operation[key.insert] = newValue
                break
            }
            operation[OperationKey.numberAdd] = .decimal(newDecimal - decimal)
        case .string(let newString):
            guard case .string(let string) = self.data else {
                operation[key.insert] = newValue
                break
            }
            let stringOperation = stringDiff(string, newString)
            operation[OperationKey.subtype] = AnyCodable(OperationalTransformSubtype.TEXT0.rawValue)
            operation[OperationKey.operation] = stringOperation
        case .undefined:
            break
        }

        return operation
    }
}
