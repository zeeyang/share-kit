import SwiftyJSON

protocol OperationalTransformer {
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
