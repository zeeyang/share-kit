import SwiftUI
import ShareKit

struct ContentView: View {
    @ObservedObject
    var model = GameViewModel()
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                List {
                    ForEach(model.players) {
                        PlayerCell(player: $0)
                    }
                }
                Button(action: {
                    model.createPlayer()
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill").resizable().frame(width: 20, height: 20)
                        Text("New Player")
                    }
                }.padding()
            }.navigationBarTitle("Leaderboard 🧪")
        }
    }
}

struct PlayerCell: View {
    @ObservedObject
    var player: PlayerViewModel
    var body: some View {
        HStack {
            TextField("Enter player name", text: $player.name)
            Spacer()
            Text(String(player.score))
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static let model = GameViewModel([
        PlayerViewModel(id: DocumentID("1", in: "players"), player: Player(name: "Ada Lovelace", score: 10)),
        PlayerViewModel(id: DocumentID("2", in: "players"), player: Player(name: "Grace Hopper", score: 20)),
        PlayerViewModel(id: DocumentID("3", in: "players"), player: Player(name: "Marie Curie", score: 30)),
    ])
    static var previews: some View {
        ContentView(model: model)
    }
}
