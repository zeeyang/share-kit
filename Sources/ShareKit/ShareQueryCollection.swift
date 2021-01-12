import Foundation
import Combine

protocol OperationalTransformQuery {
    var collection: String { get }
    var query: AnyCodable { get }
    func put(_ data: [VersionedDocumentData]) throws
    func sync(_ diffs: [ArrayChange]) throws
}

final public class ShareQueryCollection<Entity> where Entity: Codable {
    public let collection: String
    public let query: AnyCodable

    public private(set) var documents = CurrentValueSubject<[ShareDocument<Entity>], Never>([])

    var cascadeSubscription = true
    private let connection: ShareConnection

    init(_ query: AnyCodable, in collection: String, connection: ShareConnection) {
        self.collection = collection
        self.query = query
        self.connection = connection
    }

    public func create(_ data: Entity) throws -> ShareDocument<Entity> {
        return try connection.create(data, in: collection)
    }

    func subscribe(_ queryID: UInt) {
        let message = QuerySubscribeMessage(queryID: queryID, query: query, collection: collection)
        connection.send(message: message) // TODO update query collection state
    }
}

extension ShareQueryCollection: OperationalTransformQuery {
    func put(_ data: [VersionedDocumentData]) throws {
        let newDocuments: [ShareDocument<Entity>] = try data.map {
            let document: ShareDocument<Entity> = try connection.getDocument($0.document, in: collection)
            try document.put($0.data, version: $0.version, type: $0.type)
            document.subscribe()
            return document
        }
        documents.send(newDocuments)
    }

    func sync(_ diffs: [ArrayChange]) throws {
        for diff in diffs {
            switch diff {
            case .move(let from, let to, let howMany):
                let range = from..<(from + howMany)
                var changedDocuments = documents.value
                let slice = changedDocuments[range]
                changedDocuments.removeSubrange(range)
                changedDocuments.insert(contentsOf: slice, at: to)
                documents.send(changedDocuments)
            case .insert(let index, let values):
                // TODO: cascade subscription
                let docs: [ShareDocument<Entity>] = try values.map { item in
                    let doc: ShareDocument<Entity> = try connection.getDocument(item.document, in: self.collection)
                    try doc.put(item.data, version: item.version, type: item.type)
                    return doc
                }
                var changedDocuments = documents.value
                changedDocuments.insert(contentsOf: docs, at: index)
                documents.send(changedDocuments)
            case .remove(let index, let howMany):
                let range = index..<(index + howMany)
                var changedDocuments = documents.value
                changedDocuments.removeSubrange(range)
                documents.send(changedDocuments)
            }
        }
    }
}
