import SwiftyJSON

protocol OperationalTransformer {
    static func apply(_ operations: [JSON], to json: JSON) throws -> JSON
}

enum OperationalTransformError: Error {
    case emptyPath
    case pathDoesNotExist
    case missingOperationData
    case invalidJSONData
    case unsupportedSubtype
}
