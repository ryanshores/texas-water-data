import SwiftUI
import TexasWaterCore

struct DashboardSection: View {
    let title: String
    let subtitle: String
    let reservoirs: [ReservoirSummary]
    var emptyMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title3.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }

            if reservoirs.isEmpty, let emptyMessage {
                ContentUnavailableView(
                    emptyMessage,
                    systemImage: "water.waves",
                    description: Text("Pull to refresh after new observations arrive.")
                )
                .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(reservoirs.prefix(5).enumerated()), id: \.element.id) { index, reservoir in
                        NavigationLink {
                            ReservoirDetailView(reservoir: reservoir)
                        } label: {
                            ReservoirRow(reservoir: reservoir)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                        }
                        .buttonStyle(.plain)
                        if index < min(reservoirs.count, 5) - 1 {
                            Divider().padding(.leading, 68)
                        }
                    }
                }
                .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.quaternary, lineWidth: 0.5)
                }
            }
        }
    }
}
