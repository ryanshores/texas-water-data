import SwiftUI
import TexasWaterCore

struct ReservoirMapPanel: View {
    @EnvironmentObject private var store: ReservoirDataStore
    let reservoirs: [ReservoirSummary]
    @State private var isExpanded = false
    @State private var selectedReservoir: ReservoirSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reservoir map")
                .font(.headline)
                .foregroundStyle(.primary)

            TexasWaterMapView(
                droughtAreas: [],
                reservoirs: reservoirs,
                onSelectReservoir: { selectedReservoir = $0 }
            )
            .frame(height: 230)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityLabel("Map showing \(reservoirs.count) reservoirs")

            HStack {
                Text("Tap a marker for reservoir details.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Expand map", systemImage: "arrow.up.left.and.arrow.down.right") {
                    isExpanded = true
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .fullScreenCover(isPresented: $isExpanded) {
            NavigationStack {
                TexasWaterMapView(
                    droughtAreas: [],
                    reservoirs: reservoirs,
                    onSelectReservoir: { selectedReservoir = $0 }
                )
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Reservoir map")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { isExpanded = false }
                    }
                }
            }
        }
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
