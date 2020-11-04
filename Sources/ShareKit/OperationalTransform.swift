import SwiftyJSON

protocol OperationalTransformer {
    func transform(_ operations: [JSON], to json: JSON) throws -> JSON
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
    func apply(_ diffs: [ArrayChange]) throws
}

protocol MutableJSON {
    func addNumber(_ amount: Int, at path: JSONSubscriptType...) throws
    func setObject(_ object: JSON, at path: JSONSubscriptType...) throws
    func removeObject(at path: JSONSubscriptType...) throws
}

enum OperationalTransformError: Error {
    case pathDoesNotExist
    case missingOperationData
    case invalidJSONData
}
