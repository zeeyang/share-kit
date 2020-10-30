import Foundation
import SwiftyJSON

public enum OperationalTransformType: String, Codable {
    case JSON0 = "http://sharejs.org/types/JSONv0"
    case TXT0 = "http://sharejs.org/types/textv0"
}

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
    var protocolMajor: UInt?
    var protocolMinor: UInt?
    var type: OperationalTransformType?

    enum CodingKeys: String, CodingKey {
        case action = "a"
        case clientID = "id"
        case protocolMajor = "protocol"
        case protocolMinor = "protocolMinor"
        case type
    }
}

struct SubscribeMessage: Codable {
    var action = MessageAction.subscribe
    var collection: String
    var document: String
    var data: VersionedData?

    enum CodingKeys: String, CodingKey {
        case action = "a"
        case collection = "c"
        case document = "d"
        case data
    }
}

struct VersionedData: Codable {
    var data: JSON?
    var version: UInt

    enum CodingKeys: String, CodingKey {
        case data
        case version = "v"
    }
}

struct OperationMessage: Codable {
    struct CreateData: Codable {
        var type: OperationalTransformType
        var data: JSON
    }

    var action = MessageAction.operation
    var collection: String
    var document: String
    var source: String
    var data: OperationData?
    var version: UInt
    var sequence: UInt

    enum CodingKeys: String, CodingKey {
        case action = "a"
        case collection = "c"
        case document = "d"
        case source = "src"
        case sequence = "seq"
        case version = "v"
        case create
        case operations = "op"
        case delete
    }

    init(collection: String, document: String, source: String, data: OperationData, version: UInt) {
        self.collection = collection
        self.document = document
        self.source = source
        self.data = data
        self.version = version
        self.sequence = 0
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        action = try values.decode(MessageAction.self, forKey: .action)
        collection = try values.decode(String.self, forKey: .collection)
        document = try values.decode(String.self, forKey: .document)
        source = try values.decode(String.self, forKey: .source)
        version = try values.decode(UInt.self, forKey: .version)
        sequence = try values.decode(UInt.self, forKey: .sequence)

        if let updateData = try? values.decode([JSON].self, forKey: .operations) {
            data = .update(operations: updateData)
        } else if let createData = try? values.decode(CreateData.self, forKey: .create) {
            data = .create(type: createData.type, data: createData.data)
        } else if let deleteData = try? values.decode(Bool.self, forKey: .delete) {
            data = .delete(isDeleted: deleteData)
        } else {
            data = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(action, forKey: .action)
        try container.encode(collection, forKey: .collection)
        try container.encode(document, forKey: .document)
        try container.encode(source, forKey: .source)
        try container.encode(version, forKey: .version)
        try container.encode(sequence, forKey: .sequence)

        switch data {
        case .create(_, let data)?:
            try container.encode(data, forKey: .create)
        case .update(let operations)?:
            try container.encode(operations, forKey: .operations)
        case .delete(let isDeleted)?:
            try container.encode(isDeleted, forKey: .delete)
        case nil:
            break
        }
    }
}

enum OperationData {
    case create(type: OperationalTransformType, data: JSON)
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
