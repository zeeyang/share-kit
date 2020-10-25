import Foundation
import SwiftyJSON

struct GenericMessage: Decodable {
    let action: MessageAction
    let error: Error?

    struct Error: Decodable {
        let message: String
    }

    enum CodingKeys: String, CodingKey {
        case action = "a"
        case error
    }
}

struct HandshakeMessage: Codable {
    var action = MessageAction.handshake
    var clientID: String?

    enum CodingKeys: String, CodingKey {
        case action = "a"
        case clientID = "id"
    }
}

struct SubscribeMessage: Codable {
    var action = MessageAction.subscribe
    var collection: String
    var document: String
    var data: JSON

    enum CodingKeys: String, CodingKey {
        case action = "a"
        case collection = "c"
        case document = "d"
        case data
    }
}

struct OperationMessage: Codable {
    struct CreateData: Codable {
        var type: String
        var data: JSON
    }

    var action = MessageAction.operation
    var collection: String
    var document: String
    var source: String
    var data: OperationData
    var version: UInt
    var sequence: UInt?

    enum CodingKeys: String, CodingKey {
        case action = "a"
        case collection = "c"
        case document = "d"
        case source = "src"
        case sequence
        case version = "v"
        case create
        case operations = "ops"
        case delete
    }

    init(collection: String, document: String, source: String, data: OperationData, version: UInt) {
        self.collection = collection
        self.document = document
        self.source = source
        self.data = data
        self.version = version
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        action = try values.decode(MessageAction.self, forKey: .action)
        collection = try values.decode(String.self, forKey: .collection)
        document = try values.decode(String.self, forKey: .document)
        source = try values.decode(String.self, forKey: .source)
        sequence = try values.decode(UInt.self, forKey: .sequence)
        version = try values.decode(UInt.self, forKey: .version)

        if let updateData = try? values.decode([JSON].self, forKey: .operations) {
            data = .update(operations: updateData)
        } else if let createData = try? values.decode(CreateData.self, forKey: .create) {
            data = .create(type: createData.type, data: createData.data)
        } else if let deleteData = try? values.decode(Bool.self, forKey: .delete) {
            data = .delete(isDeleted: deleteData)
        } else {
            throw MessageError.unknownOperationAction
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(collection, forKey: .collection)
        try container.encode(document, forKey: .document)

        switch data {
        default: break
        }
    }
}

enum OperationData {
    case create(type: String, data: JSON)
    case update(operations: [JSON])
    case delete(isDeleted: Bool)
}

enum OperationKey: String {
    case path = "p"
    case numberAdd = "na"
    case objectInsert = "oi"
    case objectDelete = "od"
    case listInsert = "li"
    case listDelete = "ld"
}

enum MessageAction: String, Codable {
    case handshake = "hs"
    case subscribe = "s"
    case operation = "op"
}

enum MessageError: Error, LocalizedError {
    case unknownOperationAction
    public var errorDescription: String? {
        return "\(self)"
    }
}
