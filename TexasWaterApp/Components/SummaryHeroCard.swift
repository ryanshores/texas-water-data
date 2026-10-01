import SwiftUI
import TexasWaterCore

struct SummaryHeroCard: View {
    let dashboard: ReservoirDashboard
    let source: ReservoirDataStore.Source

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Texas reservoirs")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                    Text(WaterFormatting.percent(dashboard.statewidePercentFull))
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text("of conservation capacity")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Image(systemName: "water.waves")
                    .font(.system(size: 34))
                    .foregroundStyle(.white.opacity(0.85))
                    .accessibilityHidden(true)
            }

            Divider().overlay(.white.opacity(0.25))

            HStack {
                Label("\(dashboard.reservoirs.count) monitored", systemImage: "mappin.and.ellipse")
                Spacer()
                Label(freshnessLabel, systemImage: isStale ? "clock.badge.exclamationmark" : "clock")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.85))

            Text("Source: \(source.rawValue)")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [.waterBlue, Color(red: 0.03, green: 0.25, blue: 0.52)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .shadow(color: .blue.opacity(0.18), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
    }

    private var sourceDate: Date? {
        guard let value = dashboard.sourceUpdatedAt else { return nil }
        if let date = ISO8601DateFormatter().date(from: value) { return date }
        return ReservoirHistoryDecoder.parseDate(String(value.prefix(10)))
    }

    private var isStale: Bool {
        guard let sourceDate else { return true }
        return sourceDate < Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
    }

    private var freshnessLabel: String {
        guard let sourceDate else { return "Update time unknown" }
        let date = sourceDate.formatted(date: .abbreviated, time: .omitted)
        return isStale ? "Delayed · \(date)" : "Updated \(date)"
    }
}
