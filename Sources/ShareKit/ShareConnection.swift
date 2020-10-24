import Foundation
import NIO
import WebSocketKit
import SwiftyJSON

final public class ShareConnection {
    enum Error: Swift.Error, LocalizedError {
        case encodeMessage
        public var errorDescription: String? {
            return "\(self)"
        }
    }

    public private(set) var clientID: String?

    let eventLoop: EventLoop
    var webSocket: WebSocket {
        didSet {
            webSocket.onText(handleSocketText)
            initiateHandShake()
        }
    }

    init(socket: WebSocket, on eventLoop: EventLoop) {
        self.webSocket = socket
        self.eventLoop = eventLoop
        initiateHandShake()
    }

    private func initiateHandShake() {
        let message = HandshakeMessage(clientID: self.clientID)
        send(message: message).whenFailure { _ in
            let _ = self.webSocket.close()
        }
    }

    private func handleSocketText(_ socket: WebSocket, _ text: String) {
        print("received \(text)")
        guard let data = text.data(using: .utf8) else {
            return
        }
        guard let message = try? JSONDecoder().decode(GenericMessage.self, from: data) else {
            return
        }
        guard message.error == nil else {
            return
        }
        switch message.action {
        case .handshake:
            handleHandshake(data)
        default:
            break
        }
    }

    private func handleHandshake(_ data: Data) {
        guard let message = try? JSONDecoder().decode(HandshakeMessage.self, from: data) else {
            return
        }
        clientID = message.clientID
    }

    func send<T>(message: T) -> EventLoopFuture<Void> where T: Encodable {
        let promise = eventLoop.makePromise(of: Void.self)
        eventLoop.execute {
            guard let data = try? JSONEncoder().encode(message), let str = String(data: data, encoding: .utf8) else {
                promise.fail(Error.encodeMessage)
                return
            }
            print("sent \(str)")
            self.webSocket.send(str, promise: promise)
        }
        return promise.futureResult
    }
}
