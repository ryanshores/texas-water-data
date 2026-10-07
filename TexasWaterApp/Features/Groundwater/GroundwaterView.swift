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
                else { List {
                    if let error = store.errorMessage { Section { Text(error).foregroundStyle(.secondary) } }
                    controls; wells
                }.refreshable { await store.refresh() } }
            }
            .navigationTitle("Groundwater")
            .task { await store.load() }
            .toolbar {
                Button("Refresh", systemImage: "arrow.clockwise") { Task { await store.refresh() } }
                    .disabled(store.isLoading)
            }
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
    @EnvironmentObject private var store: GroundwaterDataStore
    private var chart: GroundwaterChartData { GroundwaterChartData(readings: store.histories[well.id] ?? []) }
    var body: some View {
        NavigationStack {
            List {
                Section { Text(well.aquifer); Text("\(well.county) County") }
                if let change = chart.change {
                    Section("Water-table change") {
                        Text(change >= 0 ? "Rose \(change, specifier: "%.1f") ft" : "Fell \(-change, specifier: "%.1f") ft")
                        Text("A smaller depth below land surface means the water table rose.").font(.caption).foregroundStyle(.secondary)
                        if let first = chart.points.first, let last = chart.points.last {
                            Text("\(groundwaterDateLabel(first.date)) – \(groundwaterDateLabel(last.date))").font(.caption)
                        }
                    }
                }
                if !chart.points.isEmpty {
                    Section("History") {
                        GroundwaterHistoryChart(data: chart)
                            .frame(height: 180)
                    }
                }
                if store.loadingHistoryIDs.contains(well.id) { ProgressView("Loading history…") }
                if let error = store.historyErrors[well.id] { Text(error).foregroundStyle(.secondary) }
                if !store.loadingHistoryIDs.contains(well.id), chart.points.isEmpty, store.historyErrors[well.id] == nil {
                    Text("No valid history observations are available.").foregroundStyle(.secondary)
                }
            }
            .navigationTitle(well.id)
            .task { await store.loadHistory(wellID: well.id) }
            .refreshable { await store.loadHistory(wellID: well.id) }
            .toolbar {
                Button("Refresh", systemImage: "arrow.clockwise") { Task { await store.loadHistory(wellID: well.id) } }
                    .disabled(store.loadingHistoryIDs.contains(well.id))
            }
        }
    }
}

struct GroundwaterHistoryChart: View {
    let data: GroundwaterChartData

    var body: some View {
        Chart(data.points) {
            LineMark(x: .value("Date", $0.date), y: .value("Depth below land surface", $0.ordinate))
            PointMark(x: .value("Date", $0.date), y: .value("Depth below land surface", $0.ordinate))
        }
        .chartYScale(domain: data.domain)
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let date = value.as(Date.self) { Text(groundwaterDateLabel(date)) }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let depth = value.as(Double.self) { Text("\(-depth, specifier: "%.1f")") }
                }
            }
        }
        .chartYAxisLabel("Depth below land surface (ft)")
    }

}

private func groundwaterDateLabel(_ date: Date) -> String {
    date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: .gmt))
}

private extension Array where Element: Hashable { var unique: [Element] { Array(Set(self)) } }
