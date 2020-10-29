import Foundation
import SwiftyJSON

public struct DocumentID: Hashable {
    let key: String
    let collection: String
    init(_ key: String, in collection: String) {
        self.key = key
        self.collection = collection
    }
}

public enum ShareDocumentError: Error {
    case decodeDocumentData
    case applyTransform
}

final public class ShareDocument<Entity>: Identifiable where Entity: Codable {
    enum State {
        case blank
        case pending
        case ready
        case deleted
        case invalid(Error)
    }

    public let id: DocumentID

    @Published
    public private(set) var data: Entity?
    public private(set) var version: UInt?
    var state: State

    internal private(set) var json = JSON()
    internal private(set) var transformer = JSON0Transformer()

    var inflightOperation: OperationData?
    var queuedOperations: [OperationData] = []

    private let connection: ShareConnection

    init(_ documentID: DocumentID, connection: ShareConnection, json: JSON? = nil) {
        self.id = documentID
        self.connection = connection
        self.state = .blank
    }

    public func create(_ data: JSON, type: OperationalTransformType = .JSON0) throws {
        let document = DocumentData(data: data, version: 0)
        try put(document)
        send(.create(type: type, data: document))
    }

    public func delete() {
        state = .deleted
        send(.delete(isDeleted: true))
    }

    public func subscribe() {
        let msg = SubscribeMessage(collection: id.collection, document: id.key)
        connection.send(message: msg).whenComplete { result in
            switch result {
            case .success:
                self.state = .pending
            case .failure(let error):
                self.state = .invalid(error)
            }
        }
    }
}

extension ShareDocument {
    // Apply raw JSON operation with OT transformer
    func apply(operations: [JSON]) throws {
        let newJSON = try transformer.transform(operations, to: self.json)
        try update(json: newJSON)
    }

    // Update document JSON and cast to entity
    func update(json: JSON) throws {
        let jsonData = try json.rawData()
        self.data = try JSONDecoder().decode(Entity.self, from: jsonData)
        self.json = json
    }

    // Update document version and validate version sequence
    func update(version: UInt, validateSequence: Bool) throws {
        if validateSequence, let oldVersion = self.version {
            guard version == oldVersion + 1 else {
                throw OperationalTransformError.invalidVersion
            }
        }
        self.version = version
    }

    // Send ops to server or append to ops queue
    func send(_ operation: OperationData) {
        guard inflightOperation == nil, let source = connection.clientID else {
            // TODO drop op is last is delete
            if let queueItem = queuedOperations.first,
               case .update(let queueOps) = queueItem,
               case .update(let currentOps) = operation {
                // Merge with last op group at end of queue
                self.queuedOperations[0] = .update(operations: queueOps + currentOps)
            } else {
                // Enqueue op group
                self.queuedOperations.insert(operation, at: 0)
            }
            return
        }
        let msg = OperationMessage(
            collection: id.collection,
            document: id.key,
            source: source,
            data: operation,
            version: version ?? 0
        )
        connection.send(message: msg).whenComplete { result in
            switch result {
            case .success:
                self.inflightOperation = operation
            case .failure:
                // Put op group back to beginning of queue
                self.queuedOperations.append(operation)
                self.inflightOperation = nil
            }
        }
    }
}
