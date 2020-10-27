import Foundation
import NIO
import WebSocketKit
import SwiftyJSON

final public class ShareConnection {
    enum Error: Swift.Error, LocalizedError {
        case encodeMessage
        case documentEntityType
        public var errorDescription: String? {
            return "\(self)"
        }
    }

    public private(set) var clientID: String?

    let eventLoop: EventLoop
    var webSocket: WebSocket {
        didSet {
            initiateSocket()
        }
    }

    private var documentStore = [DocumentID: OperationalTransformDocument]()

    init(socket: WebSocket, on eventLoop: EventLoop) {
        self.webSocket = socket
        self.eventLoop = eventLoop
        initiateSocket()
    }

    public func getDocument<Entity>(_ key: String, in collection: String) throws -> ShareDocument<Entity> {
        let documentID = DocumentID(key, in: collection)
        let document: ShareDocument<Entity>
        if documentStore[documentID] != nil {
            guard let storedDocument = documentStore[documentID] as? ShareDocument<Entity> else {
                throw Error.documentEntityType
            }
            document = storedDocument
        } else {
            document = ShareDocument<Entity>(documentID, connection: self)
        }
        documentStore[documentID] = document
        return document
    }

    public func subscribe<Entity>(_ key: String, in collection: String) throws -> ShareDocument<Entity> {
        let document: ShareDocument<Entity> = try getDocument(key, in: collection)
        document.subscribe()
        return document
    }

    func send<Message>(message: Message) -> EventLoopFuture<Void> where Message: Encodable {
        let promise = eventLoop.makePromise(of: Void.self)
        eventLoop.execute {
            guard let data = try? JSONEncoder().encode(message),
                  let messageString = String(data: data, encoding: .utf8) else {
                promise.fail(Error.encodeMessage)
                return
            }
            print("sent \(messageString)")
            self.webSocket.send(messageString, promise: promise)
        }
        return promise.futureResult
    }
}

private extension ShareConnection {
    func initiateSocket() {
        webSocket.onText(handleSocketText)
        let message = HandshakeMessage(clientID: self.clientID)
        send(message: message).whenFailure { _ in
            let _ = self.webSocket.close()
        }
    }

    func handleSocketText(_ socket: WebSocket, _ text: String) {
        print("received \(text)")
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(GenericMessage.self, from: data) else {
            return
        }
        guard message.error == nil else {
            handleErrorMessage(message)
            return
        }
        switch message.action {
        case .handshake:
            handleHandshakeMessage(data)
        case .subscribe:
            handleSubscribeMessage(data)
        case .operation:
            break
        }
    }

    func handleHandshakeMessage(_ data: Data) {
        guard let message = try? JSONDecoder().decode(HandshakeMessage.self, from: data) else {
            return
        }
        clientID = message.clientID
    }

    func handleSubscribeMessage(_ data: Data) {
        guard let message = try? JSONDecoder().decode(SubscribeMessage.self, from: data), let data = message.data else {
            return
        }
        let documentID = DocumentID(message.key, in: message.collection)
        guard let document = documentStore[documentID] else {
            return
        }
        document.put(data)
    }

    func handleErrorMessage(_ message: GenericMessage) {
        guard let error = message.error else {
            return
        }
        print("error \(error.message)")
    }
}
