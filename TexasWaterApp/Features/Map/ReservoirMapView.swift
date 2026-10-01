import MapKit
import SwiftUI
import TexasWaterCore

struct ReservoirMapView: View {
    @EnvironmentObject private var store: ReservoirDataStore
    @State private var selectedReservoir: ReservoirSummary?
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 31.2, longitude: -99.3),
            span: MKCoordinateSpan(latitudeDelta: 7.8, longitudeDelta: 8.8)
        )
    )

    var body: some View {
        NavigationStack {
            Map(position: $position) {
                ForEach(store.reservoirs) { reservoir in
                    Annotation(
                        reservoir.shortName,
                        coordinate: CLLocationCoordinate2D(
                            latitude: reservoir.latitude,
                            longitude: reservoir.longitude
                        ),
                        anchor: .bottom
                    ) {
                        Button { selectedReservoir = reservoir } label: {
                            Image(systemName: reservoir.status.systemImage)
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(7)
                                .background(Color.reservoirStatus(reservoir.status), in: Circle())
                                .shadow(radius: 2, y: 1)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(reservoir.shortName), \(WaterFormatting.percent(reservoir.percentFull))")
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .navigationTitle("Map")
            .sheet(item: $selectedReservoir) { reservoir in
                NavigationStack {
                    ReservoirDetailView(reservoir: reservoir)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { selectedReservoir = nil }
                            }
                        }
                }
                .environmentObject(store)
                .presentationDetents([.medium, .large])
            }
        }
    }
}
