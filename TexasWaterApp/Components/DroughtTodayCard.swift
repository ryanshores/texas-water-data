import SwiftUI
import TexasWaterCore

struct DroughtTodayCard: View {
    let summary: DroughtSummary
    let source: DroughtDataStore.Source
    let onOpenDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Label("Texas drought", systemImage: "sun.max.fill")
                    .font(.headline)
                Spacer()
                Text(summary.highestCategory)
                    .font(.title3.bold())
                    .foregroundStyle(categoryColor)
                    .accessibilityLabel("Highest active drought category \(summary.highestCategory)")
            }

            Text("Statewide conditions")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                metric(title: "D0+", value: summary.droughtCoverage, color: .orange)
                metric(title: "D2+", value: summary.severeOrWorseCoverage, color: .red)
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Week over week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("D0+ \(WaterFormatting.change(summary.weekOverWeek["D0"] ?? nil))")
                        .font(.subheadline.weight(.semibold))
                    Text("D2+ \(WaterFormatting.change(summary.weekOverWeek["D2"] ?? nil))")
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("Map week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(summary.mapDate)
                        .font(.subheadline.weight(.semibold))
                    Text(source.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: onOpenDetails) {
                Label("View drought details", systemImage: "chevron.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.waterBlue)
            .accessibilityHint("Opens the drought map and county history")
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.orange.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func metric(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(WaterFormatting.percent(value))
                .font(.title2.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) coverage \(WaterFormatting.percent(value))")
    }

    private var categoryColor: Color {
        switch summary.highestCategory {
        case "D4": return .purple
        case "D3": return .red
        case "D2": return .orange
        case "D1": return .yellow
        case "D0": return .teal
        default: return .green
        }
    }
}
