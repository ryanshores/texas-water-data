import SwiftUI
import TexasWaterCore

struct ContentView: View {
    private enum Tab: Hashable {
        case today
        case reservoirs
        case map
        case basins
        case drought
        case about
    }

    @StateObject private var store = ReservoirDataStore()
    @StateObject private var alerts = LocalAlertManager()
    @ObservedObject private var deepLinkInbox = TexasWaterDeepLinkInbox.shared
    @State private var selectedTab: Tab = .today
    @State private var pendingReservoirID: String?
    @State private var deepLinkedReservoir: ReservoirSummary?

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "drop.fill") }
                .tag(Tab.today)

            ReservoirListView()
                .tabItem { Label("Reservoirs", systemImage: "list.bullet") }
                .tag(Tab.reservoirs)

            ReservoirMapView()
                .tabItem { Label("Map", systemImage: "map") }
                .tag(Tab.map)

            BasinListView()
                .tabItem { Label("Basins", systemImage: "water.waves") }
                .tag(Tab.basins)

            DroughtView()
                .tabItem { Label("Drought", systemImage: "sun.max") }
                .tag(Tab.drought)

            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(Tab.about)
        }
        .tint(Color.waterBlue)
        .environmentObject(store)
        .environmentObject(alerts)
        .task {
            await store.load()
            if let url = deepLinkInbox.takePendingURL() {
                open(url)
            }
        }
        .onOpenURL(perform: open)
        .onChange(of: store.reservoirs) { _, _ in presentPendingReservoirIfAvailable() }
        .onChange(of: store.dashboard) { _, dashboard in
            guard let dashboard else { return }
            Task { await alerts.evaluate(dashboard: dashboard, favorites: store.favoriteIDs) }
        }
        .onChange(of: deepLinkInbox.pendingURL) { _, url in
            guard let url else { return }
            open(url)
            _ = deepLinkInbox.takePendingURL()
        }
        .sheet(item: $deepLinkedReservoir) { reservoir in
            NavigationStack {
                ReservoirDetailView(reservoir: reservoir)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { deepLinkedReservoir = nil }
                        }
                    }
            }
        }
    }

    private func open(_ url: URL) {
        switch TexasWaterDeepLink.destination(for: url) {
        case .today:
            selectedTab = .today
        case let .reservoir(id):
            selectedTab = .reservoirs
            pendingReservoirID = id
            presentPendingReservoirIfAvailable()
        case nil:
            break
        }
    }

    private func presentPendingReservoirIfAvailable() {
        guard let identifier = pendingReservoirID,
              let reservoir = store.reservoirs.first(where: {
                  $0.id.caseInsensitiveCompare(identifier) == .orderedSame
                      || $0.slug.caseInsensitiveCompare(identifier) == .orderedSame
              }) else {
            return
        }
        pendingReservoirID = nil
        deepLinkedReservoir = reservoir
    }
}

#Preview {
    ContentView()
}
