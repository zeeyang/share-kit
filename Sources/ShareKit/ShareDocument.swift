import Foundation
import SwiftyJSON

public struct DocumentID: Hashable {
    let key: String
    let collection: String

    public init(_ key: String, in collection: String) {
        self.key = key
        self.collection = collection
    }
}

final public class ShareDocument<Entity>: Identifiable where Entity: Codable {
    enum ShareDocumentError: Error {
        case transformType
        case documentState
        case decodeDocumentData
        case operationalTransformType
        case applyTransform
        case subscription
        case operationVersion
        case operationAck
    }

    enum State: Equatable {
        case paused
        case pending
        case ready
        case deleted
        case invalid(ShareDocumentError)
    }

    public let id: DocumentID

    @Published
    public private(set) var data: Entity?
    public private(set) var version: UInt?
    public private(set) var json = JSON()

    var state: State //TODO private setter and state transitions

    var documentTransformer: OperationalTransformer.Type?
    var transformer: OperationalTransformer.Type {
        return documentTransformer ?? connection.defaultTransformer
    }

    var inflightOperation: OperationData?
    var queuedOperations: [OperationData] = []

    let connection: ShareConnection

    init(_ documentID: DocumentID, connection: ShareConnection) {
        self.id = documentID
        self.connection = connection
        self.state = .paused
    }

    public func create(_ data: Entity, type: OperationalTransformType? = nil) throws {
        let jsonData = try JSONEncoder().encode(data)
        let json = JSON(jsonData)
        try put(json, version: 0, type: type)
        send(.create(type: type ?? connection.defaultTransformer.type, data: json))
    }

    public func delete() {
        state = .deleted
        send(.delete(isDeleted: true))
    }

    public func subscribe() {
        guard state == .paused else {
            print("Document subscribe canceled: \(state)")
            return
        }
        let msg = SubscribeMessage(collection: id.collection, document: id.key, version: version)
        connection.send(message: msg).whenComplete { result in
            switch result {
            case .success:
                self.state = .pending
            case .failure:
                self.state = .invalid(.subscription)
            }
        }
    }
}

extension ShareDocument {
    // Apply raw JSON operation with OT transformer
    func apply(operations: [JSON]) throws {
        let newJSON = try transformer.apply(operations, to: self.json)
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
                throw ShareDocumentError.operationVersion
            }
        }
        self.version = version
    }

    // Send ops to server or append to ops queue
    func send(_ operation: OperationData) {
        guard inflightOperation == nil, let source = connection.clientID, let version = version else {
            if let queueItem = queuedOperations.first,
               case .update(let queueOps) = queueItem,
               case .update(let currentOps) = operation {
                // Merge with last op group at end of queue
                var newOps = queueOps
                for operation in currentOps {
                    newOps = transformer.append(operation, to: newOps)
                }
                self.queuedOperations[0] = .update(operations: newOps)
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
            version: version
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
