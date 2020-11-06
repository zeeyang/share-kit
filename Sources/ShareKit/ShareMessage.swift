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
    var version: UInt?
    var data: VersionedData?

    enum CodingKeys: String, CodingKey {
        case action = "a"
        case collection = "c"
        case document = "d"
        case version = "v"
        case data
    }
}

struct QuerySubscribeMessage: Codable {
    var action = MessageAction.querySubscribe
    var queryID: UInt
    var query: JSON?
    var collection: String?
    var data: [VersionedDocumentData]?

    enum CodingKeys: String, CodingKey {
        case action = "a"
        case collection = "c"
        case queryID = "id"
        case query = "q"
        case data
    }
}

struct VersionedDocumentData: Codable {
    var document: String
    var data: JSON?
    var version: UInt

    enum CodingKeys: String, CodingKey {
        case document = "d"
        case data
        case version = "v"
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

struct QueryMessage: Codable {
    var action = MessageAction.query
    var queryID: UInt
    var diff: [ArrayChange]

    enum CodingKeys: String, CodingKey {
        case action = "a"
        case queryID = "id"
        case diff
    }
}

enum ArrayChange: Codable {
    case move(from: Int, to: Int, howMany: Int)
    case insert(index: Int, values: [JSON])
    case remove(index: Int, howMany: Int)

    enum ArrayChangeType: String, Codable {
        case move, insert, remove
    }

    enum CodingKeys: String, CodingKey {
        case type
        case from
        case to
        case index
        case howMany
        case values
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let type = try values.decode(ArrayChangeType.self, forKey: .type)
        switch type {
        case .move:
            let from = try values.decode(Int.self, forKey: .from)
            let to = try values.decode(Int.self, forKey: .to)
            let howMany = try values.decode(Int.self, forKey: .howMany)
            self = .move(from: from, to: to, howMany: howMany)
        case .insert:
            let index = try values.decode(Int.self, forKey: .index)
            let newValues = try values.decode([JSON].self, forKey: .values)
            self = .insert(index: index, values: newValues)
        case .remove:
            let index = try values.decode(Int.self, forKey: .index)
            let howMany = try values.decode(Int.self, forKey: .howMany)
            self = .remove(index: index, howMany: howMany)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .move(let from, let to, let howMany):
            try container.encode(ArrayChangeType.move, forKey: .type)
            try container.encode(from, forKey: .from)
            try container.encode(to, forKey: .to)
            try container.encode(howMany, forKey: .howMany)
        case .insert(let index, let values):
            try container.encode(ArrayChangeType.insert, forKey: .type)
            try container.encode(index, forKey: .index)
            try container.encode(values, forKey: .values)
        case .remove(let index, let howMany):
            try container.encode(ArrayChangeType.remove, forKey: .type)
            try container.encode(index, forKey: .index)
            try container.encode(howMany, forKey: .howMany)
        }
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

enum OperationKey {
    static let path = "p"
    static let numberAdd = "na"
    static let objectInsert = "oi"
    static let objectDelete = "od"
    static let listInsert = "li"
    static let listDelete = "ld"
}

enum MessageAction: String, Codable {
    case handshake = "hs"
    case subscribe = "s"
    case query = "q"
    case querySubscribe = "qs"
    case operation = "op"
}
