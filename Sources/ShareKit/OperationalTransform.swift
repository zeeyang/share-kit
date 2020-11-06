import SwiftyJSON

protocol OperationalTransformer {
    func apply(_ operations: [JSON], to json: JSON) throws -> JSON
}

protocol OperationalTransformDocument {
    func pause()
    func resume()
    func put(_ data: JSON?, version: UInt) throws
    func sync(_ data: OperationData, version: UInt) throws
    func ack(version: UInt, sequence: UInt) throws
    func rollback(_ data: OperationData?, version: UInt) throws
}

protocol OperationalTransformQuery {
    var collection: String { get }
    var query: JSON { get }
    func put(_ data: [VersionedDocumentData]) throws
    func sync(_ diffs: [ArrayChange]) throws
}

enum OperationalTransformError: Error {
    case emptyPath
    case pathDoesNotExist
    case missingOperationData
    case invalidJSONData
}
