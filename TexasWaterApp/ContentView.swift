import SwiftUI

struct ContentView: View {
    @StateObject private var store = ReservoirDataStore()

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "drop.fill") }

            ReservoirListView()
                .tabItem { Label("Reservoirs", systemImage: "list.bullet") }

            ReservoirMapView()
                .tabItem { Label("Map", systemImage: "map") }

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .tint(.waterBlue)
        .environmentObject(store)
        .task { await store.load() }
    }
}

#Preview {
    ContentView()
}
