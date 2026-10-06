import Charts
import SwiftUI
import TexasWaterCore

struct GroundwaterView: View {
    @EnvironmentObject private var store: GroundwaterDataStore
    @State private var county = "All counties"
    @State private var aquifer = "All aquifers"
    @State private var favoritesOnly = false
    @State private var selectedWell: GroundwaterWell?

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading && store.wells.isEmpty { ProgressView("Loading monitoring wells…") }
                else if let error = store.errorMessage, store.wells.isEmpty { ContentUnavailableView("Groundwater unavailable", systemImage: "drop.triangle", description: Text(error)) }
                else { List { controls; wells } }
            }
            .navigationTitle("Groundwater")
            .task { await store.load() }
            .sheet(item: $selectedWell) { GroundwaterDetailView(well: $0) }
        }
    }

    private var controls: some View {
        Section {
            Toggle("Favorites only", isOn: $favoritesOnly)
            Picker("County", selection: $county) { Text("All counties").tag("All counties"); ForEach(store.wells.map(\.county).unique.sorted(), id: \.self) { Text($0).tag($0) } }
            Picker("Aquifer", selection: $aquifer) { Text("All aquifers").tag("All aquifers"); ForEach(store.wells.map(\.aquifer).unique.sorted(), id: \.self) { Text($0).tag($0) } }
        }
    }

    private var wells: some View {
        Section("Monitoring wells") {
            ForEach(filtered) { well in
                Button { selectedWell = well } label: {
                    HStack { VStack(alignment: .leading) { Text(well.id).font(.headline); Text("\(well.aquifer) · \(well.county) County").font(.caption).foregroundStyle(.secondary) }
                        Spacer(); VStack(alignment: .trailing) { Text(well.depthBelowLandSurface.map { String(format: "%.1f ft", $0) } ?? "—"); Text("below land").font(.caption2).foregroundStyle(.secondary); Text(well.observedAt ?? "No observation date").font(.caption2).foregroundStyle(.secondary) }
                    }
                }.tint(.primary).swipeActions { Button { store.toggleFavorite(well) } label: { Label(store.favoriteIDs.contains(well.id) ? "Unfavorite" : "Favorite", systemImage: "star") }.tint(.yellow) }
            }
        }
    }
    private var filtered: [GroundwaterWell] { store.wells.filter { (county == "All counties" || $0.county == county) && (aquifer == "All aquifers" || $0.aquifer == aquifer) && (!favoritesOnly || store.favoriteIDs.contains($0.id)) } }
}

private struct GroundwaterDetailView: View {
    let well: GroundwaterWell
    @State private var readings: [GroundwaterReading] = []
    @State private var error: String?
    var body: some View {
        NavigationStack {
            List {
                Section { Text(well.aquifer); Text("\(well.county) County") }
                if let change = GroundwaterTrend.waterTableChange(readings: readings) {
                    Section("Water-table change") {
                        Text(change >= 0 ? "Rose \(change, specifier: "%.1f") ft" : "Fell \(-change, specifier: "%.1f") ft")
                        Text("A smaller depth below land surface means the water table rose.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !readings.isEmpty {
                    Section("History") {
                        Chart(readings) { LineMark(x: .value("Date", $0.date), y: .value("Depth below land surface", $0.depthBelowLandSurface)) }
                            .chartYScale(domain: (readings.map(\.depthBelowLandSurface).max() ?? 1)...(readings.map(\.depthBelowLandSurface).min() ?? 0))
                            .frame(height: 180)
                    }
                }
                if let error { Text(error).foregroundStyle(.secondary) }
            }
            .navigationTitle(well.id)
            .task {
                do { readings = try await TexasWaterAPIClient(baseURL: AppEnvironment.backendURL!).fetchGroundwaterHistory(wellID: well.id) }
                catch { self.error = error.localizedDescription }
            }
        }
    }
}

private extension Array where Element: Hashable { var unique: [Element] { Array(Set(self)) } }
