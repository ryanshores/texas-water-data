import SwiftUI
import TexasWaterCore

struct BasinListView: View {
    @EnvironmentObject private var store: ReservoirDataStore

    var body: some View {
        NavigationStack {
            List(store.basinSummaries) { basin in
                NavigationLink { BasinDetailView(basin: basin) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(basin.name).font(.headline)
                            Spacer()
                            Text(WaterFormatting.percent(basin.percentFull)).font(.headline.monospacedDigit())
                        }
                        Text("\(basin.includedReservoirCount) reservoirs with storage data · \(WaterFormatting.acreFeet(basin.conservationCapacity)) capacity")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                }
            }
            .overlay {
                if store.basinSummaries.isEmpty {
                    ContentUnavailableView("Basins unavailable", systemImage: "water.waves", description: Text("Refresh after reservoir data loads."))
                }
            }
            .navigationTitle("Basins")
            .refreshable { await store.refresh() }
        }
    }
}

struct BasinDetailView: View {
    let basin: BasinSummary
    @EnvironmentObject private var store: ReservoirDataStore

    var body: some View {
        List {
            Section("Basin conditions") {
                LabeledContent("Percent full", value: WaterFormatting.percent(basin.percentFull))
                LabeledContent("Conservation storage", value: WaterFormatting.acreFeet(basin.conservationStorage))
                LabeledContent("Conservation capacity", value: WaterFormatting.acreFeet(basin.conservationCapacity))
                LabeledContent("Included reservoirs", value: "\(basin.includedReservoirCount) of \(basin.reservoirs.count)")
                LabeledContent("Latest source update", value: basin.sourceUpdatedAt ?? "—")
            }
            Section("Largest reservoirs") {
                ForEach(basin.reservoirs.prefix(5)) { reservoir in
                    NavigationLink { ReservoirDetailView(reservoir: reservoir) } label: {
                        ReservoirRow(reservoir: reservoir, capacityContext: store.capacityContext)
                    }
                }
            }
            if basin.reservoirs.count > 5 {
                Section("Other reservoirs") {
                    ForEach(Array(basin.reservoirs.dropFirst(5))) { reservoir in
                        NavigationLink { ReservoirDetailView(reservoir: reservoir) } label: {
                            ReservoirRow(reservoir: reservoir, capacityContext: store.capacityContext)
                        }
                    }
                }
            }
        }
        .navigationTitle("\(basin.name) Basin")
    }
}
