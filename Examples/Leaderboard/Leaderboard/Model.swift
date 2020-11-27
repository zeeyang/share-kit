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

    init() {
        ShareClient(eventLoopGroupProvider: .createNew).connect("ws://localhost:8080") { connection in
            guard let collection: ShareQueryCollection<Player> = try? connection.subscribe(query: ["$sort": ["score": -1]], in: "players") else {
                return
            }
            collection.$documents
                .receive(on: RunLoop.main)
                .map { documents in
                    self.playerBag.removeAll()
                    return documents.map { PlayerViewModel($0, bag: &self.playerBag) }
                }
                .assign(to: \.players, on: self)
                .store(in: &self.gameBag)
            self.playerCollection = collection
        }
    }

    init(_ players: [PlayerViewModel]) {
        self.players = players
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
        document.$data
            .compactMap { $0?.name }
            .receive(on: RunLoop.main)
            .assign(to: \.name, on: self)
            .store(in: &bag)
        document.$data
            .compactMap { $0?.score }
            .receive(on: RunLoop.main)
            .assign(to: \.score, on: self)
            .store(in: &bag)
        $name
            .dropFirst()
            .sink { value in
                try? document.set(string: value, at: "name")
            }
            .store(in: &bag)
    }

    init(id: DocumentID, player: Player) {
        self.id = id
        self.name = player.name
        self.score = player.score
    }

    func bumpScore(_ score: Int = 5) throws {
        if let document = document {
            try document.change(amount: score, at: "score")
        } else {
            self.score += score
        }
    }
}
