import Foundation
import NIO
import NIOConcurrencyHelpers
import WebSocketKit

public final class ShareClient {
    public enum EventLoopGroupProvider {
        case shared(EventLoopGroup)
        case createNew
    }

    public struct Configuration {
        public var reconnect: Bool

        public init(reconnect: Bool = true) {
            self.reconnect = reconnect
        }
    }

    public enum Error: Swift.Error, LocalizedError {
        case alreadyShutdown
        public var errorDescription: String? {
            return "\(self)"
        }
    }

    private let eventLoopGroupProvider: EventLoopGroupProvider
    private let eventLoopGroup: EventLoopGroup
    private let configuration: Configuration
    private let isShutdown = NIOAtomic.makeAtomic(value: false)

    public init(eventLoopGroupProvider: EventLoopGroupProvider, configuration: Configuration = .init()) {
        self.eventLoopGroupProvider = eventLoopGroupProvider
        switch self.eventLoopGroupProvider {
        case .shared(let group):
            self.eventLoopGroup = group
        case .createNew:
            self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        }
        self.configuration = configuration
    }

    public func connect(
        _ url: String,
        connection: ShareConnection? = nil,
        onConnect: @escaping (ShareConnection) -> Void
    ) {
        let eventLoop = connection?.eventLoop ?? eventLoopGroup.next()
        let wsFuture = WebSocket.connect(to: url, on: eventLoopGroup) { socket in
            if let existingConnection = connection {
                existingConnection.webSocket = socket
            } else {
                let connection = ShareConnection(socket: socket, on: eventLoop)
                socket.onClose.whenComplete { _ in
                    guard self.configuration.reconnect else {
                        return
                    }
                    eventLoop.execute {
                        self.connect(url, connection: connection, onConnect: onConnect)
                    }
                }
                onConnect(connection)
            }
        }
        wsFuture.whenFailure { _ in
            guard self.configuration.reconnect else {
                return
            }
            eventLoop.scheduleTask(in: .seconds(1)) {
                self.connect(url, connection: connection, onConnect: onConnect)
            }
        }
    }

    public func syncShutdown() throws {
        switch self.eventLoopGroupProvider {
        case .shared:
            return
        case .createNew:
            if self.isShutdown.compareAndExchange(expected: false, desired: true) {
                try self.eventLoopGroup.syncShutdownGracefully()
            } else {
                throw WebSocketClient.Error.alreadyShutdown
            }
        }
    }

    deinit {
        switch self.eventLoopGroupProvider {
        case .shared:
            return
        case .createNew:
            assert(self.isShutdown.load(), "ShareClient not shutdown before deinit.")
        }
    }
}
