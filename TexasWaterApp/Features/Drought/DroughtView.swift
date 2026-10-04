import MapKit
import SwiftUI
import TexasWaterCore

struct DroughtView: View {
    @StateObject private var store = DroughtDataStore()
    @State private var countyName = ""

    var body: some View {
        NavigationStack {
            Group {
                if let summary = store.summary {
                    droughtContent(summary)
                } else if store.isLoading {
                    ProgressView("Loading drought conditions…")
                } else {
                    ContentUnavailableView("Drought data unavailable", systemImage: "sun.max.trianglebadge.exclamationmark", description: Text(store.errorMessage ?? "Try again shortly."))
                }
            }
            .navigationTitle("Drought")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { Task { await store.refresh() } } label: { Image(systemName: "arrow.clockwise") }.disabled(store.isLoading) } }
            .task { await store.load() }
            .refreshable { await store.refresh() }
        }
    }

    @ViewBuilder
    private func droughtContent(_ summary: DroughtSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Texas drought monitor").font(.title2.bold())
                    Text("Map week of \(summary.mapDate)").foregroundStyle(.secondary)
                    Text("\(summary.droughtCoverage, specifier: "%.1f")% of Texas is abnormally dry or worse")
                        .font(.headline)
                }
                .padding(.horizontal)

                categoryGrid(summary)
                droughtMap(summary)
                countyLookup
                Text("Week-over-week change").font(.headline).padding(.horizontal)
                ForEach(["D0", "D1", "D2", "D3", "D4"], id: \.self) { category in
                    let value = summary.weekOverWeek[category] ?? nil
                    HStack { Text(category).font(.headline).frame(width: 42, alignment: .leading); Text(value.map { String(format: "%+.1f pts", $0) } ?? "Not available").foregroundStyle((value ?? 0) >= 0 ? .red : .green) }
                        .padding(.horizontal)
                }
                Text("Source: U.S. Drought Monitor via the Texas Water Development Board.").font(.footnote).foregroundStyle(.secondary).padding()
            }
            .padding(.vertical)
        }
    }

    private var countyLookup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("County history").font(.headline)
            HStack {
                TextField("County name, e.g. Travis", text: $countyName)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit { Task { await store.loadCounty(named: countyName) } }
                Button("Check") { Task { await store.loadCounty(named: countyName) } }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isLoadingCounty || countyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let record = store.countyRecords.last {
                HStack {
                    Text(record.county).font(.headline)
                    Spacer()
                    Text(record.latestCategory).font(.headline).foregroundStyle(color(for: record.latestCategory))
                    Text(record.mapDate).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }

    private func categoryGrid(_ summary: DroughtSummary) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 105))], spacing: 10) {
            ForEach(["None", "D0", "D1", "D2", "D3", "D4"], id: \.self) { category in
                VStack(alignment: .leading, spacing: 4) { Text(category).font(.headline); Text("\(summary.categories[category] ?? 0, specifier: "%.1f")%").font(.title3.bold()).foregroundStyle(color(for: category)) }
                    .frame(maxWidth: .infinity, alignment: .leading).padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }.padding(.horizontal)
    }

    private func droughtMap(_ summary: DroughtSummary) -> some View {
        Map(initialPosition: .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 31.0, longitude: -99.9), span: MKCoordinateSpan(latitudeDelta: 9, longitudeDelta: 10)))) {
            ForEach(summary.mapAreas) { area in
                if let coordinate = centroid(area.coordinates) {
                    Annotation(area.category, coordinate: coordinate) { Circle().fill(color(for: area.category)).frame(width: 22, height: 22).overlay(Text(area.category).font(.caption2.bold()).foregroundStyle(.white)) }
                }
            }
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .accessibilityLabel("Texas drought category map")
    }

    private func centroid(_ polygons: [[[[Double]]]]) -> CLLocationCoordinate2D? {
        let points = polygons.flatMap { $0 }.flatMap { $0 }.compactMap { pair -> CLLocationCoordinate2D? in guard pair.count > 1 else { return nil }; return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0]) }
        guard !points.isEmpty else { return nil }
        return CLLocationCoordinate2D(latitude: points.map(\.latitude).reduce(0, +) / Double(points.count), longitude: points.map(\.longitude).reduce(0, +) / Double(points.count))
    }

    private func color(for category: String) -> Color { switch category { case "D4": .purple; case "D3": .red; case "D2": .orange; case "D1": .yellow; case "D0": .mint; default: .blue } }
}
