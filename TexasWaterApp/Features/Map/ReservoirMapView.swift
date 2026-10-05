import MapKit
import SwiftUI
import TexasWaterCore

struct ReservoirMapView: View {
    @EnvironmentObject private var store: ReservoirDataStore
    @EnvironmentObject private var droughtStore: DroughtDataStore
    @State private var selectedReservoir: ReservoirSummary?

    var body: some View {
        NavigationStack {
            TexasWaterMapView(
                droughtAreas: droughtStore.summary?.mapAreas ?? [],
                reservoirs: store.reservoirs,
                onSelectReservoir: { selectedReservoir = $0 }
            )
            .ignoresSafeArea(edges: .bottom)
            .accessibilityLabel("Texas map showing drought areas and reservoirs")
            .navigationTitle("Map")
            .task { await droughtStore.loadOverview() }
            .sheet(item: $selectedReservoir) { reservoir in
                NavigationStack {
                    ReservoirDetailView(reservoir: reservoir)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { selectedReservoir = nil }
                            }
                        }
                }
                .environmentObject(store)
                .presentationDetents([.medium, .large])
            }
        }
    }
}
