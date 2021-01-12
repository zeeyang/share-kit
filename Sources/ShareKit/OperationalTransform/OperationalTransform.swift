let OperationalTransformTypes: [OperationalTransformType: OperationalTransformer.Type] = [
    OperationalTransformType.JSON0: JSON0Transformer.self,
    OperationalTransformType.TEXT0: TEXT0Transformer.self
]

protocol OperationalTransformer {
    static var type: OperationalTransformType { get }
    static func apply(_ operations: [AnyCodable], to data: AnyCodable) throws -> AnyCodable
    static func inverse(_ operations: [AnyCodable]) throws -> [AnyCodable]
}

enum OperationalTransformError: Error {
    case invalidPath
    case pathDoesNotExist
    case missingOperationData
    case invalidJSONData
    case unsupportedSubtype
    case indexOutOfRange
    case oldDataMismatch
    case unsupportedOperation
}
