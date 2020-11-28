import SwiftyJSON

let OperationalTransformTypes: [OperationalTransformType: OperationalTransformer.Type] = [
    OperationalTransformType.JSON0: JSON0Transformer.self,
    OperationalTransformType.TEXT0: TEXT0Transformer.self
]

protocol OperationalTransformer {
    static var type: OperationalTransformType { get }
    static func apply(_ operations: [JSON], to json: JSON) throws -> JSON
    static func append(_ operations: JSON, to previousOperations: [JSON]) -> [JSON]
    // TODO static func inverse(_ operations: [JSON])
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
