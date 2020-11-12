<p align="center">
    <img 
        src="https://user-images.githubusercontent.com/2062827/99033720-68b0b080-2530-11eb-975c-26d404e102be.png" 
        height="160" 
        alt="ShareKit"
    >
    <br>
    <a href="LICENSE">
        <img src="http://img.shields.io/badge/license-MIT-brightgreen.svg" alt="MIT License">
    </a>
    <a href="https://swift.org">
        <img src="http://img.shields.io/badge/swift-5.2-brightgreen.svg" alt="Swift 5.2">
    </a>
    <a href="https://github.com/zeeyang/share-kit/actions">
        <img src="https://github.com/zeeyang/share-kit/workflows/build/badge.svg" alt="Continuous Integration">
    </a>
</p>

# ShareKit

Realtime data sync for Swift using ShareDB. Idiomatically designed to work with Combine and SwiftUI.

## Features
- Memory and bandwidth efficient data synchronization using Operational Transform (OT)
- Modern Swift API specifically designed for Combine and SwiftUI
- Battle-tested, MIT licensed ShareDB server that can scale with any project

## Example Usage
Note: working knowledge of Combine is required.

### Establish connection
ShareKit uses Apple official SwiftNIO framework for Websocket connections. `ShareConnection` is ShareKit's abstraction of the Websocket connection, which manages automatic re-connections and threading using `EventLoopGroup`. To connect to a ShareDB server instance, simply pass the endpoint URL and closure for connection callback.
```swift
ShareClient(eventLoopGroupProvider: .createNew).connect("ws://localhost:8080") { connection in
    print("Connected to ShareDB")
}
```

### Subscribe to documents
ShareDB document is composed of an unique ID, incremental version number, and a data payload with schemaless JSON. To subscribe to a document, first define a `Codable` struct to decode the document data entity.
```swift
struct Player: Codable {
    var name: String = ""
    var score: Int = 0
}
```
Use `connection.subscribe(...)` to send document subscription request.
```swift
ShareClient(eventLoopGroupProvider: .createNew).connect("ws://localhost:8080") { connection in
    let document: ShareDocument<Player> = connection.subscribe("doc1", in: "collection")
}
```
`ShareDocument` uses Combine publisher, `ShareDocument.$data`, to broadcast document updates.
```swift
ShareClient(eventLoopGroupProvider: .createNew).connect("ws://localhost:8080") { connection in
    let document: ShareDocument<Player> = connection.subscribe("doc1", in: "collection")
    document.$data
        .compactMap { $0 }
        .receive(on: RunLoop.main)
        .sink { player in
            print(player)
        }
        .store(in: &bag)
}
```
