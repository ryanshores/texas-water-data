import Charts
import SwiftUI
import TexasWaterCore

struct ReservoirDetailView: View {
    enum ChartRange: String, CaseIterable, Identifiable {
        case thirtyDays = "30D"
        case oneYear = "1Y"
        var id: String { rawValue }
    }

    let reservoir: ReservoirSummary

    @EnvironmentObject private var store: ReservoirDataStore
    @State private var chartRange: ChartRange = .thirtyDays

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                overview
                historySection
                metrics
                sourceSection
            }
            .padding()
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .navigationTitle(reservoir.shortName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { store.toggleFavorite(reservoir) } label: {
                    Image(systemName: store.isFavorite(reservoir) ? "star.fill" : "star")
                        .foregroundStyle(store.isFavorite(reservoir) ? .yellow : .primary)
                }
                .accessibilityLabel(store.isFavorite(reservoir) ? "Remove favorite" : "Add favorite")
            }
        }
        .task { await store.loadHistory(for: reservoir) }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(WaterFormatting.percent(reservoir.percentFull))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Spacer()
                Label(reservoir.status.label, systemImage: reservoir.status.systemImage)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.reservoirStatus(reservoir.status))
            }

            ProgressView(value: min(max(reservoir.percentFull ?? 0, 0), 100), total: 100)
                .tint(Color.reservoirStatus(reservoir.status))
                .accessibilityLabel("Percent full")
                .accessibilityValue(WaterFormatting.percent(reservoir.percentFull))

            HStack {
                if let change = reservoir.trend.sevenDays {
                    TrendLabel(change: change)
                } else {
                    Text("Seven-day change is not available yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Observed \(reservoir.observedAt)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Percent full history").font(.headline)
                Spacer()
                Picker("Chart range", selection: $chartRange) {
                    ForEach(ChartRange.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 130)
            }

            if !chartObservations.isEmpty {
                Chart(chartObservations, id: \.date) { observation in
                    if let percentFull = observation.percentFull {
                        AreaMark(
                            x: .value("Date", observation.date),
                            yStart: .value("Chart floor", chartDomain.lowerBound),
                            yEnd: .value("Percent full", percentFull)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.waterBlue.opacity(0.35), Color.waterBlue.opacity(0.03)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        LineMark(
                            x: .value("Date", observation.date),
                            y: .value("Percent full", percentFull)
                        )
                        .foregroundStyle(Color.waterBlue)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }
                }
                .chartYScale(domain: chartDomain)
                .chartYAxisLabel("Percent full")
                .frame(height: 220)
                .accessibilityLabel("Percent full history chart")
            } else if store.loadingHistoryIDs.contains(reservoir.id) {
                ProgressView("Loading history…").frame(maxWidth: .infinity, minHeight: 220)
            } else {
                ContentUnavailableView(
                    "History unavailable",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Current conditions are still available above.")
                )
                .frame(minHeight: 220)
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }

    private var metrics: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current measurements").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(title: "Water level", value: WaterFormatting.feet(reservoir.elevation), icon: "ruler")
                MetricCard(
                    title: "From conservation pool",
                    value: WaterFormatting.feet(reservoir.heightFromConservationPool),
                    icon: "arrow.up.and.down"
                )
                MetricCard(title: "Storage", value: WaterFormatting.acreFeet(reservoir.reservoirStorage), icon: "cylinder")
                MetricCard(title: "Surface area", value: WaterFormatting.acres(reservoir.surfaceArea), icon: "square.dashed")
                MetricCard(title: "Capacity", value: WaterFormatting.acreFeet(reservoir.conservationCapacity), icon: "gauge.with.dots.needle.67percent")
                MetricCard(title: "Basin", value: reservoir.basin ?? "—", icon: "map")
            }
        }
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About this data").font(.headline)
            Text("Percent full is based on conservation storage and does not include water in the flood pool. Values are best estimates and may be revised by the Texas Water Development Board.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let url = URL(string: "https://waterdatafortexas.org/reservoirs/individual/\(reservoir.slug)") {
                Link(destination: url) {
                    Label("View official reservoir page", systemImage: "arrow.up.right.square")
                }
                .font(.footnote.bold())
            }
        }
        .padding(.bottom, 20)
    }

    private var chartObservations: [ReservoirObservation] {
        let observations = store.historyByReservoirID[reservoir.id] ?? []
        guard chartRange == .thirtyDays, let latest = observations.last?.date else { return observations }
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: latest) ?? .distantPast
        return observations.filter { $0.date >= cutoff }
    }

    private var chartDomain: ClosedRange<Double> {
        let values = chartObservations.compactMap(\.percentFull)
        guard let minimum = values.min(), let maximum = values.max() else { return 0...100 }
        let lowerBound = max(0, minimum - 5)
        let upperBound = max(lowerBound + 10, maximum + 5)
        return lowerBound...upperBound
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(Color.waterBlue).accessibilityHidden(true)
            Text(value).font(.headline).lineLimit(2).minimumScaleFactor(0.75)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}
