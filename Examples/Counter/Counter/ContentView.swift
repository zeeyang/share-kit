import SwiftUI

struct ContentView: View {
    @ObservedObject
    var model = CounterViewModel()
    var body: some View {
        Text("You clicked \(model.counter.numClicks) times.")
            .padding()
        Button(action: {
            model.bumpCounter()
        }, label: {
            Text("+1")
        })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
