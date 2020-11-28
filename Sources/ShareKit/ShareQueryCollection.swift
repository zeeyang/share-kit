import Foundation
import NIO
import SwiftyJSON

protocol OperationalTransformQuery {
    var collection: String { get }
    var query: JSON { get }
    func put(_ data: [VersionedDocumentData]) throws
    func sync(_ diffs: [ArrayChange]) throws
}

final public class ShareQueryCollection<Entity> where Entity: Codable {
    public let collection: String
    public let query: JSON

    @Published
    public private(set) var documents: [ShareDocument<Entity>] = []

    var cascadeSubscription = true
    private let connection: ShareConnection

    init(_ query: JSON, in collection: String, connection: ShareConnection) {
        self.collection = collection
        self.query = query
        self.connection = connection
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
        documents = newDocuments
    }

    func sync(_ diffs: [ArrayChange]) throws {
        for diff in diffs {
            switch diff {
            case .move(let from, let to, let howMany):
                let range = from..<(from + howMany)
                let slice = documents[range]
                documents.removeSubrange(range)
                documents.insert(contentsOf: slice, at: to)
            case .insert(let index, let values):
                // TODO: cascade subscription
                let docs: [ShareDocument<Entity>] = try values.map { json in
                    let doc: ShareDocument<Entity> = try connection.getDocument(json["d"].stringValue, in: self.collection) // TODO decoder for json
                    let type = OperationalTransformType(rawValue: json["type"].stringValue)
                    try doc.put(json, version: json["v"].uIntValue, type: type)
                    return doc
                }
                documents.insert(contentsOf: docs, at: index)
            case .remove(let index, let howMany):
                let range = index..<(index + howMany)
                documents.removeSubrange(range)
            }
        }
    }
}
