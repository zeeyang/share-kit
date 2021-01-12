import SwiftUI
import Combine
import ShareKit

struct Player: Codable {
    var name: String = ""
    var score: Int = 0
}

class GameViewModel: ObservableObject {
    @Published
    var players = [PlayerViewModel]()

    private var playerCollection: ShareQueryCollection<Player>?

    private var gameBag = Set<AnyCancellable>()
    private var playerBag = Set<AnyCancellable>()
    private var client: ShareClient?

    init() {
        let client = ShareClient(eventLoopGroupProvider: .createNew)
        client.connect("ws://localhost:8080") { connection in
            guard let collection: ShareQueryCollection<Player> = try? connection.subscribe(query: ["$sort": ["score": -1]], in: "players") else {
                return
            }
            collection.documents
                .receive(on: RunLoop.main)
                .map { documents in
                    self.playerBag.removeAll()
                    return documents.map { PlayerViewModel($0, bag: &self.playerBag) }
                }
                .assign(to: \.players, on: self)
                .store(in: &self.gameBag)
            self.playerCollection = collection
        }
        self.client = client
    }

    init(_ players: [PlayerViewModel]) {
        self.players = players
    }

    deinit {
        try? client?.syncShutdown()
    }

    func createPlayer() -> ShareDocument<Player>? {
        return try? playerCollection?.create(Player())
    }

    func deletePlayer(at indexSet: IndexSet) {
        indexSet
            .lazy
            .compactMap { self.playerCollection?.documents.value[$0] }
            .forEach { $0.delete() }
    }
}

class PlayerViewModel: ObservableObject, Identifiable {
    let id: DocumentID

    @Published
    var name = ""
    @Published
    var score = 0

    private var document: ShareDocument<Player>?

    init(_ document: ShareDocument<Player>, bag: inout Set<AnyCancellable>) {
        self.id = document.id
        self.document = document
        document.value
            .compactMap { $0?.name }
            .receive(on: RunLoop.main)
            .assign(to: \.name, on: self)
            .store(in: &bag)
        document.value
            .compactMap { $0?.score }
            .receive(on: RunLoop.main)
            .assign(to: \.score, on: self)
            .store(in: &bag)
        $name
            .dropFirst()
            .sink { value in
                do {
                    try document.change {
                        try $0.name.set(value)
                    }
                } catch {
                    print(error)
                }
            }
            .store(in: &bag)
    }

    init(id: DocumentID, player: Player) {
        self.id = id
        self.name = player.name
        self.score = player.score
    }

    func bumpScore(_ increment: Int = 5) throws {
        if let document = document {
            try document.change {
                try $0.score.set(score + increment)
            }
        } else {
            self.score += increment
        }
    }
}
