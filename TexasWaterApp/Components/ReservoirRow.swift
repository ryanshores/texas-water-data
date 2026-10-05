import SwiftUI
import TexasWaterCore

struct ReservoirRow: View {
    let reservoir: ReservoirSummary
    var showsFavorite = true
    var capacityContext: ReservoirCapacityContext? = nil

    @EnvironmentObject private var store: ReservoirDataStore

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(reservoir.status.color.opacity(0.14))
                    .frame(width: 42, height: 42)
                Image(systemName: reservoir.status.systemImage)
                    .foregroundStyle(reservoir.status.color)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(reservoir.shortName)
                        .font(.headline)
                        .lineLimit(1)
                    if showsFavorite, store.isFavorite(reservoir) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("Favorite")
                    }
                }
                Text(reservoir.basin.map { "\($0) Basin" } ?? reservoir.status.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let capacityContext {
                    Text("\(capacityContext.tier(for: reservoir).rawValue) capacity")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.waterBlue)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(WaterFormatting.percent(reservoir.percentFull))
                    .font(.headline.monospacedDigit())
                if let change = reservoir.trend.sevenDays {
                    TrendLabel(change: change, compact: true)
                } else {
                    Text(reservoir.status.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(reservoir.shortName), \(WaterFormatting.percent(reservoir.percentFull)), \(reservoir.status.label)")
    }
}

struct TrendLabel: View {
    let change: Double
    var compact = false

    var body: some View {
        Label(WaterFormatting.change(change), systemImage: icon)
            .font(compact ? .caption2 : .subheadline.weight(.semibold))
            .foregroundStyle(color)
            .accessibilityLabel("\(direction), \(WaterFormatting.change(abs(change))) in seven days")
    }

    private var icon: String {
        if change > 0 { return "arrow.up.right" }
        if change < 0 { return "arrow.down.right" }
        return "arrow.right"
    }

    private var direction: String {
        if change > 0 { return "Rising" }
        if change < 0 { return "Falling" }
        return "Unchanged"
    }

    private var color: Color {
        if change > 0 { return .blue }
        if change < 0 { return .orange }
        return .secondary
    }
}
