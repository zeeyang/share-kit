import Foundation
import Combine

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
        case stateEvent
        case decodeDocumentData
        case operationalTransformType
        case applyTransform
        case subscription
        case operationVersion
        case operationAck
    }

    public let id: DocumentID

    public private(set) var value: CurrentValueSubject<Entity?, Never>
    public private(set) var version: UInt?
    private var data: AnyCodable?

    private(set) var state: State

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
        self.state = .blank
        self.value = CurrentValueSubject(nil)
    }

    public func create(_ entity: Entity, type: OperationalTransformType? = nil) throws {
        let jsonData = try JSONEncoder().encode(entity)
        let json = try AnyCodable(data: jsonData)
        try put(json, version: 0, type: type)
        send(.create(type: type ?? connection.defaultTransformer.type, data: json))
    }

    public func delete() {
        try? trigger(event: .delete)
        self.send(.delete(isDeleted: true))
    }

    public func subscribe() {
        guard state == .blank else {
            print("Document subscribe canceled: \(state)")
            return
        }
        let msg = SubscribeMessage(collection: id.collection, document: id.key, version: version)
        connection.send(message: msg).whenComplete { result in
            switch result {
            case .success:
                try? self.trigger(event: .fetch)
            case .failure:
                try? self.trigger(event: .fail)
            }
        }
    }

    public func change(onChange: (JSON0Proxy) throws -> Void) throws {
        guard let data = data else {
            return
        }
        let transaction = Transaction()
        let proxy = JSON0Proxy(path: [], data: data, transaction: transaction)
        try onChange(proxy)

        guard !transaction.operations.isEmpty else {
            return
        }
        try apply(operations: transaction.operations)
        send(.update(operations: transaction.operations))
    }
}

extension ShareDocument {
    enum State: Equatable {
        case blank
        case paused
        case pending
        case ready
        case deleted
        case fetchError
    }

    enum Event {
        case fetch
        case put
        case apply
        case pause
        case resume
        case delete
        case fail
    }

    typealias Transition = () throws -> State

    func makeTransition(for event: Event) throws -> Transition {
        switch (state, event) {
        case (.blank, .fetch):
            return { .pending }
        case (.blank, .put), (.pending, .put), (.ready, .put):
            return { .ready }
        case (.ready, .pause):
            return { .paused }
        case (.paused, .resume), (.ready, .resume):
            return { .ready }
        case (.paused, .apply):
            return { .paused }
        case (.ready, .apply):
            return { .ready }
        case (.ready, .delete), (.paused, .delete):
            return { .deleted }
        case (.blank, .fail), (.pending, .fail):
            return { .fetchError }
        default:
            throw ShareDocumentError.stateEvent
        }
    }

    func trigger(event: Event) throws {
        let transition = try makeTransition(for: event)
        state = try transition()
    }
}

extension ShareDocument {
    // Apply raw JSON operation with OT transformer
    func apply(operations: [AnyCodable]) throws {
        guard let data = self.data else {
            return
        }
        try trigger(event: .apply)
        let newJSON = try transformer.apply(operations, to: data)
        try update(json: newJSON)
    }

    // Update document JSON and cast to entity
    func update(json: AnyCodable) throws {
        let data = try JSONEncoder().encode(json)
        self.value.send(try JSONDecoder().decode(Entity.self, from: data))
        self.data = json
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
            queuedOperations.insert(operation, at: 0)
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
