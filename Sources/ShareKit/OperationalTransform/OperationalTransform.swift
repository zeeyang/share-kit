import SwiftyJSON

protocol OperationalTransformer {
    static func apply(_ operations: [JSON], to json: JSON) throws -> JSON
    // TODO static func inverse(_ operations: [JSON])
    // TODO static func merge(_ operations: [JSON], with previousOperations: [JSON])
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
