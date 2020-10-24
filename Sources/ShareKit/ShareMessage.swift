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
    var action = MessageAction.operation
    var collection: String
    var document: String
    var source: String

    enum CodingKeys: String, CodingKey {
        case action = "a"
        case collection = "c"
        case document = "d"
        case source = "src"
    }
}

enum MessageAction: String, Codable {
    case handshake = "hs"
    case subscribe = "s"
    case operation = "op"
}
