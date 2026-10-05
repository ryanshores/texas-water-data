import MapKit
import SwiftUI
import TexasWaterCore

struct DroughtMapView: View {
    let areas: [DroughtMapArea]
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TexasWaterMapView(droughtAreas: areas, reservoirs: [])
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .accessibilityLabel("Texas drought map showing all D0 through D4 drought areas")
            HStack {
                Text("Shaded areas show the full drought footprint. Colors match the categories above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Expand map", systemImage: "arrow.up.left.and.arrow.down.right") {
                    isExpanded = true
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
            }
        }
        .fullScreenCover(isPresented: $isExpanded) {
            NavigationStack {
                TexasWaterMapView(droughtAreas: areas, reservoirs: [])
                    .ignoresSafeArea(edges: .bottom)
                    .navigationTitle("Drought map")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { isExpanded = false }
                        }
                    }
            }
        }
    }
}
