import Charts
import MapKit
import SwiftUI
import TexasWaterCore

struct DroughtView: View {
    @EnvironmentObject private var store: DroughtDataStore
    @State private var selectedCountyID = ""

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
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { Task { await store.refreshAll() } } label: { Image(systemName: "arrow.clockwise") }.disabled(store.isLoading || store.isLoadingHydrologyContext) } }
            .task { await store.load() }
            .refreshable { await store.refreshAll() }
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
                hydrologyContext
                countyLookup
                Text("Week-over-week change").font(.headline).padding(.horizontal)
                ForEach(["D0", "D1", "D2", "D3", "D4"], id: \.self) { category in
                    let value = summary.weekOverWeek[category] ?? nil
                    HStack { Text(category).font(.headline).frame(width: 42, alignment: .leading); Text(value.map { String(format: "%+.1f pts", $0) } ?? "Not available").foregroundStyle((value ?? 0) >= 0 ? .red : .green) }
                        .padding(.horizontal)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Source: \(store.source.rawValue)")
                    Text("Original data: U.S. Drought Monitor via the Texas Water Development Board.")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding()
            }
            .padding(.vertical)
        }
    }

    private var countyLookup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("County history").font(.headline)
            Picker("County", selection: $selectedCountyID) {
                Text("Select a county").tag("")
                ForEach(store.counties) { county in
                    Text(county.county).tag(county.id)
                }
            }
            .pickerStyle(.menu)
            .tint(.waterBlue)
            .onChange(of: selectedCountyID) { _, identifier in
                guard let county = store.counties.first(where: { $0.id == identifier }) else { return }
                Task { await store.loadCounty(named: county.queryName) }
            }
            .disabled(store.counties.isEmpty || store.isLoadingCounty)

            if store.counties.isEmpty {
                Label("Loading county list…", systemImage: "arrow.triangle.2.circlepath")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let record = store.countyRecords.last {
                countyDetail(record)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func countyDetail(_ record: DroughtCountyRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(record.county).font(.headline)
                    Text("Week of \(record.mapDate)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(record.latestCategory).font(.title3.bold()).foregroundStyle(color(for: record.latestCategory))
            }
            Text("\(record.categories["D0"] ?? 0, specifier: "%.1f")% of county area is abnormally dry or worse")
                .font(.subheadline)
            if let boundary = store.countyDetail?.boundary {
                CountyBoundaryMap(boundary: boundary, color: color(for: record.latestCategory))
                    .frame(height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Map of \(record.county)")
            }
            countyChart
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var countyChart: some View {
        let history = Array(store.countyRecords.suffix(26))
        if history.count > 1 {
            VStack(alignment: .leading, spacing: 6) {
                Text("Six-month drought coverage").font(.subheadline.bold())
                Chart(history) { item in
                    if let date = ReservoirHistoryDecoder.parseDate(item.mapDate) {
                        LineMark(
                            x: .value("Week", date),
                            y: .value("D0+ coverage", item.categories["D0"] ?? 0)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(by: .value("Drought threshold", "D0+"))
                        LineMark(
                            x: .value("Week", date),
                            y: .value("D2+ coverage", item.categories["D2"] ?? 0)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(by: .value("Drought threshold", "D2+"))
                    }
                }
                .chartYScale(domain: 0...100)
                .chartForegroundStyleScale(["D0+": .orange, "D2+": .red])
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let percent = value.as(Double.self) {
                                Text("\(percent.formatted(.number.precision(.fractionLength(0))))%")
                            }
                        }
                    }
                }
                .chartYAxisLabel("County area in drought", position: .leading)
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 160)
                VStack(alignment: .leading, spacing: 4) {
                    Text("How to read this chart").font(.caption.bold())
                    Text("D0+ (orange) is the percent of county area that is abnormally dry or worse. D2+ (red) is the percent in severe drought or worse. The status badge above is the current highest category affecting any part of the county; it is a status label, not a third line.")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
            }
        }
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
        DroughtMapView(areas: summary.mapAreas)
            .padding(.horizontal)
    }

    @ViewBuilder
    private var hydrologyContext: some View {
        if let context = store.hydrologyContext {
            DroughtHydrologyContextView(context: context)
        } else if store.isLoadingHydrologyContext {
            HStack(spacing: 10) {
                ProgressView()
                Text("Loading soil moisture, streamflow, and drought indices…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        } else if let error = store.hydrologyContextErrorMessage {
            Label(error, systemImage: "wifi.exclamationmark")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }

    private func color(for category: String) -> Color { switch category { case "D4": .purple; case "D3": .red; case "D2": .orange; case "D1": .yellow; case "D0": .mint; default: .blue } }
}
