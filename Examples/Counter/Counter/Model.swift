import SwiftUI
import Combine
import ShareKit

struct Counter: Codable {
    var numClicks = 0
}

class CounterViewModel: ObservableObject {
    @Published
    var counter = Counter()

    private var document: ShareDocument<Counter>?
    private var bag = Set<AnyCancellable>()

    init() {
        ShareClient(eventLoopGroupProvider: .createNew).connect("ws://localhost:8080") { connection in
            guard let document: ShareDocument<Counter> = try? connection.subscribe(document: "counter", in: "examples") else {
                return
            }
            document.$data
                .compactMap { $0 }
                .receive(on: RunLoop.main)
                .assign(to: \.counter, on: self)
                .store(in: &self.bag)
            self.document = document
        }
    }

    func bumpCounter() {
        try? document?.change(amount: 1, at: "numClicks")
    }
}
