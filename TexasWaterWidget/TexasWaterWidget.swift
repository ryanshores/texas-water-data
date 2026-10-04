import SwiftUI
import TexasWaterCore
import WidgetKit

struct TexasWaterWidgetEntry: TimelineEntry {
    let date: Date
    let dashboard: ReservoirDashboard?
    let favoriteIDs: Set<String>
    let isUsingCachedData: Bool
}

struct TexasWaterWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TexasWaterWidgetEntry {
        TexasWaterWidgetEntry(
            date: .now,
            dashboard: previewDashboard,
            favoriteIDs: ["travis"],
            isUsingCachedData: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (TexasWaterWidgetEntry) -> Void) {
        Task { @MainActor in
            completion(await entry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<TexasWaterWidgetEntry>) -> Void) {
        Task { @MainActor in
            let snapshot = await entry()
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 2, to: snapshot.date) ?? snapshot.date
            completion(Timeline(entries: [snapshot], policy: .after(nextUpdate)))
        }
    }

    private func entry() async -> TexasWaterWidgetEntry {
        let favorites = SharedWaterData.favoriteIDs
        let cached = SharedWaterData.loadDashboard()
        do {
            let snapshots = try await TWDBClient().fetchCurrentConditions()
            let dashboard = ReservoirCatalogBuilder.build(from: snapshots)
            SharedWaterData.saveDashboard(dashboard)
            return TexasWaterWidgetEntry(
                date: .now,
                dashboard: dashboard,
                favoriteIDs: favorites,
                isUsingCachedData: false
            )
        } catch {
            return TexasWaterWidgetEntry(
                date: .now,
                dashboard: cached,
                favoriteIDs: favorites,
                isUsingCachedData: true
            )
        }
    }

    private var previewDashboard: ReservoirDashboard {
        ReservoirDashboard(
            generatedAt: "2026-10-02T00:00:00Z",
            sourceUpdatedAt: "2026-10-02",
            statewidePercentFull: 73.4,
            reservoirs: [
                ReservoirSummary(
                    id: "travis",
                    slug: "travis",
                    shortName: "Travis",
                    fullName: "Lake Travis",
                    observedAt: "2026-10-02",
                    latitude: 30.4,
                    longitude: -97.9,
                    basin: "Colorado",
                    region: nil,
                    isWaterSupply: true,
                    isFloodControl: false,
                    percentFull: 48.1,
                    elevation: nil,
                    surfaceArea: nil,
                    reservoirStorage: nil,
                    conservationStorage: nil,
                    conservationCapacity: nil,
                    conservationPoolElevation: nil,
                    trend: ReservoirTrend(sevenDays: -1.4)
                ),
                ReservoirSummary(
                    id: "buchanan",
                    slug: "buchanan",
                    shortName: "Buchanan",
                    fullName: "Lake Buchanan",
                    observedAt: "2026-10-02",
                    latitude: 30.7,
                    longitude: -98.4,
                    basin: "Colorado",
                    region: nil,
                    isWaterSupply: true,
                    isFloodControl: false,
                    percentFull: 80.5,
                    elevation: nil,
                    surfaceArea: nil,
                    reservoirStorage: nil,
                    conservationStorage: nil,
                    conservationCapacity: nil,
                    conservationPoolElevation: nil
                )
            ]
        )
    }
}

struct TexasWaterWidget: Widget {
    let kind = "TexasWaterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TexasWaterWidgetProvider()) { entry in
            TexasWaterWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color(red: 0.03, green: 0.25, blue: 0.52) }
        }
        .configurationDisplayName("Texas Water")
        .description("See Texas reservoir conditions at a glance.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular,
        ])
    }
}

struct TexasWaterWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TexasWaterWidgetEntry

    var body: some View {
        Group {
            if let dashboard = entry.dashboard {
                if family == .systemSmall {
                    smallDashboard(dashboard)
                } else if family == .accessoryInline {
                    inlineDashboard(dashboard)
                } else if family == .accessoryCircular {
                    circularDashboard(dashboard)
                } else if family == .accessoryRectangular {
                    rectangularDashboard(dashboard)
                } else {
                    mediumDashboard(dashboard)
                }
            } else {
                unavailable
            }
        }
        .foregroundStyle(.white)
    }

    private func smallDashboard(_ dashboard: ReservoirDashboard) -> some View {
        let focus = preferredReservoir(in: dashboard)
        return VStack(alignment: .leading, spacing: 6) {
            Label("Texas Water", systemImage: "drop.fill")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.85))
            Text(focus?.shortName ?? "Texas reservoirs")
                .font(.headline)
                .lineLimit(1)
            Text(percent(focus?.percentFull ?? dashboard.statewidePercentFull))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .allowsTightening(true)
            Text(focus == nil ? "statewide conservation capacity" : statusLabel(for: focus!))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            Spacer(minLength: 0)
            freshness
        }
        .padding()
        .widgetURL(focus.map { TexasWaterDeepLink.reservoirURL(id: $0.id) } ?? TexasWaterDeepLink.todayURL)
    }

    private func mediumDashboard(_ dashboard: ReservoirDashboard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Texas Water", systemImage: "water.waves")
                    .font(.headline)
                Spacer()
                Text(percent(dashboard.statewidePercentFull))
                    .font(.headline.monospacedDigit())
            }
            Text("Statewide conservation capacity")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))

            ForEach(featuredReservoirs(in: dashboard)) { reservoir in
                Link(destination: TexasWaterDeepLink.reservoirURL(id: reservoir.id)) {
                    HStack {
                        Text(reservoir.shortName).lineLimit(1)
                        Spacer()
                        Text(percent(reservoir.percentFull)).monospacedDigit()
                        Text(statusLabel(for: reservoir))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            freshness
        }
        .padding()
        .widgetURL(TexasWaterDeepLink.todayURL)
    }

    private func inlineDashboard(_ dashboard: ReservoirDashboard) -> some View {
        let focus = preferredReservoir(in: dashboard)
        return Text("\(focus?.shortName ?? "Texas") \(percent(focus?.percentFull ?? dashboard.statewidePercentFull))")
            .widgetURL(focus.map { TexasWaterDeepLink.reservoirURL(id: $0.id) } ?? TexasWaterDeepLink.todayURL)
    }

    private func circularDashboard(_ dashboard: ReservoirDashboard) -> some View {
        let focus = preferredReservoir(in: dashboard)
        let value = (focus?.percentFull ?? dashboard.statewidePercentFull ?? 0) / 100
        return Gauge(value: min(max(value, 0), 1)) {
            Text(focus?.shortName ?? "Texas")
        } currentValueLabel: {
            Text(percent(focus?.percentFull ?? dashboard.statewidePercentFull))
                .minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetURL(focus.map { TexasWaterDeepLink.reservoirURL(id: $0.id) } ?? TexasWaterDeepLink.todayURL)
    }

    private func rectangularDashboard(_ dashboard: ReservoirDashboard) -> some View {
        let focus = preferredReservoir(in: dashboard)
        return VStack(alignment: .leading) {
            Text(focus?.shortName ?? "Texas reservoirs")
                .font(.headline)
                .lineLimit(1)
            Text(percent(focus?.percentFull ?? dashboard.statewidePercentFull))
                .font(.title2.monospacedDigit())
            Text(focus.map(statusLabel(for:)) ?? "Statewide")
                .font(.caption)
        }
        .widgetURL(focus.map { TexasWaterDeepLink.reservoirURL(id: $0.id) } ?? TexasWaterDeepLink.todayURL)
    }

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Texas Water", systemImage: "drop.fill")
                .font(.headline)
            Text("Water data is unavailable")
                .font(.subheadline)
            Text("Open the app to refresh when you are connected.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding()
        .widgetURL(TexasWaterDeepLink.todayURL)
    }

    private var freshness: some View {
        Label(entry.isUsingCachedData ? "Saved data" : "Updated now", systemImage: entry.isUsingCachedData ? "clock" : "arrow.clockwise")
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.7))
    }

    private func preferredReservoir(in dashboard: ReservoirDashboard) -> ReservoirSummary? {
        dashboard.reservoirs.first { entry.favoriteIDs.contains($0.id) }
            ?? dashboard.reservoirs.first { $0.status == .critical || $0.status == .low }
            ?? dashboard.reservoirs.first
    }

    private func featuredReservoirs(in dashboard: ReservoirDashboard) -> [ReservoirSummary] {
        let favorites = dashboard.reservoirs.filter { entry.favoriteIDs.contains($0.id) }
        if !favorites.isEmpty { return Array(favorites.prefix(3)) }
        let urgent = dashboard.reservoirs.filter { $0.status == .critical || $0.status == .low }
        return Array((urgent.isEmpty ? dashboard.reservoirs : urgent).prefix(3))
    }

    private func percent(_ value: Double?) -> String {
        value.map { $0.formatted(.number.precision(.fractionLength(1))) + "%" } ?? "—"
    }

    private func statusLabel(for reservoir: ReservoirSummary) -> String {
        switch reservoir.status {
        case .nearFull: return "Near full"
        case .normal: return "Normal"
        case .low: return "Low"
        case .critical: return "Critically low"
        case .unavailable: return "Unavailable"
        }
    }
}

@main
struct TexasWaterWidgetBundle: WidgetBundle {
    var body: some Widget {
        TexasWaterWidget()
    }
}
