import MapKit
import SwiftUI
import TexasWaterCore

struct TexasWaterMapView: UIViewRepresentable {
    let droughtAreas: [DroughtMapArea]
    let reservoirs: [ReservoirSummary]
    var onSelectReservoir: (ReservoirSummary) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.isPitchEnabled = false
        map.isRotateEnabled = false
        map.showsCompass = true
        map.showsScale = true
        map.pointOfInterestFilter = .excludingAll
        map.setRegion(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 31.2, longitude: -99.3),
                span: MKCoordinateSpan(latitudeDelta: 7.8, longitudeDelta: 8.8)
            ),
            animated: false
        )
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.onSelectReservoir = onSelectReservoir
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations)

        let polygons = droughtAreas.flatMap { makePolygons(for: $0) }
        map.addOverlays(polygons)
        map.addAnnotations(droughtAreas.compactMap(makeCategoryAnnotation))
        map.addAnnotations(reservoirs.map(ReservoirAnnotation.init))

        var rect = polygons.map(\.boundingMapRect).reduce(MKMapRect.null) { $0.union($1) }
        for reservoir in reservoirs {
            let point = MKMapPoint(CLLocationCoordinate2D(latitude: reservoir.latitude, longitude: reservoir.longitude))
            rect = rect.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
        }
        if !rect.isNull {
            map.setVisibleMapRect(
                rect,
                edgePadding: UIEdgeInsets(top: 28, left: 28, bottom: 28, right: 28),
                animated: false
            )
        }
    }

    private func makePolygons(for area: DroughtMapArea) -> [MKPolygon] {
        area.coordinates.compactMap { rings in
            let convertedRings = rings.compactMap(makeCoordinates)
            guard let outer = convertedRings.first, outer.count > 2 else { return nil }

            let interiors = convertedRings.dropFirst().compactMap { ring -> MKPolygon? in
                guard ring.count > 2 else { return nil }
                var coordinates = ring
                return MKPolygon(coordinates: &coordinates, count: coordinates.count)
            }

            var coordinates = outer
            let polygon = MKPolygon(
                coordinates: &coordinates,
                count: coordinates.count,
                interiorPolygons: interiors
            )
            polygon.title = area.category
            return polygon
        }
    }

    private func makeCoordinates(_ ring: [[Double]]) -> [CLLocationCoordinate2D]? {
        let coordinates = ring.compactMap { pair -> CLLocationCoordinate2D? in
            guard pair.count > 1 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
        }
        return coordinates.count > 2 ? coordinates : nil
    }

    private func makeCategoryAnnotation(for area: DroughtMapArea) -> MKPointAnnotation? {
        let points = area.coordinates
            .flatMap { $0 }
            .flatMap { $0 }
            .compactMap { pair -> CLLocationCoordinate2D? in
                guard pair.count > 1 else { return nil }
                return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
            }
        guard !points.isEmpty else { return nil }

        let annotation = MKPointAnnotation()
        annotation.title = area.category
        annotation.coordinate = CLLocationCoordinate2D(
            latitude: points.map(\.latitude).reduce(0, +) / Double(points.count),
            longitude: points.map(\.longitude).reduce(0, +) / Double(points.count)
        )
        return annotation
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onSelectReservoir: (ReservoirSummary) -> Void = { _ in }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polygon = overlay as? MKPolygon else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let color = Self.color(for: polygon.title)
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.strokeColor = color.withAlphaComponent(0.8)
            renderer.fillColor = color.withAlphaComponent(0.28)
            renderer.lineWidth = 1
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let cluster = annotation as? MKClusterAnnotation {
                return clusterView(for: cluster, in: mapView)
            }

            if let reservoirAnnotation = annotation as? ReservoirAnnotation {
                let identifier = "reservoir"
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view.annotation = annotation
                view.glyphImage = UIImage(systemName: Self.symbol(for: reservoirAnnotation.reservoir.status))
                view.glyphText = nil
                view.markerTintColor = Self.color(for: reservoirAnnotation.reservoir.status)
                view.clusteringIdentifier = "reservoirs"
                view.displayPriority = .defaultHigh
                view.titleVisibility = .hidden
                view.subtitleVisibility = .hidden
                view.accessibilityLabel = "\(reservoirAnnotation.reservoir.shortName), \(WaterFormatting.percent(reservoirAnnotation.reservoir.percentFull))"
                return view
            }

            let identifier = "drought-category"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.annotation = annotation
            view.glyphText = (annotation.title ?? nil) ?? "?"
            view.markerTintColor = Self.color(for: (annotation.title ?? nil))
            view.displayPriority = .required
            view.titleVisibility = .hidden
            view.subtitleVisibility = .hidden
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let cluster = view.annotation as? MKClusterAnnotation {
                zoom(to: cluster, on: mapView)
                return
            }
            guard let annotation = view.annotation as? ReservoirAnnotation else { return }
            onSelectReservoir(annotation.reservoir)
        }

        private func clusterView(for cluster: MKClusterAnnotation, in mapView: MKMapView) -> MKMarkerAnnotationView {
            let identifier = "reservoir-cluster"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: cluster, reuseIdentifier: identifier)
            let reservoirs = cluster.memberAnnotations.compactMap { ($0 as? ReservoirAnnotation)?.reservoir }
            let percentFull = Self.weightedPercent(for: reservoirs)

            view.annotation = cluster
            view.glyphImage = nil
            view.glyphText = "\(reservoirs.count)"
            view.markerTintColor = Self.color(for: ReservoirStatus.classify(percentFull: percentFull))
            view.clusteringIdentifier = "reservoirs"
            view.displayPriority = .required
            view.canShowCallout = true
            view.titleVisibility = .hidden
            view.subtitleVisibility = .hidden

            let summary = UILabel()
            summary.text = "\(reservoirs.count) reservoirs · \(WaterFormatting.percent(percentFull)) full"
            summary.font = .preferredFont(forTextStyle: .subheadline)
            summary.sizeToFit()
            view.detailCalloutAccessoryView = summary
            view.accessibilityLabel = "\(reservoirs.count) reservoirs, \(WaterFormatting.percent(percentFull)) full"
            return view
        }

        private func zoom(to cluster: MKClusterAnnotation, on mapView: MKMapView) {
            var rect = MKMapRect.null
            for member in cluster.memberAnnotations {
                let coordinate = member.coordinate
                let point = MKMapPoint(coordinate)
                rect = rect.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
            }
            guard !rect.isNull else { return }
            mapView.deselectAnnotation(cluster, animated: false)
            mapView.setVisibleMapRect(
                rect,
                edgePadding: UIEdgeInsets(top: 80, left: 60, bottom: 80, right: 60),
                animated: true
            )
        }

        private static func weightedPercent(for reservoirs: [ReservoirSummary]) -> Double? {
            let paired = reservoirs.compactMap { reservoir -> (storage: Double, capacity: Double)? in
                guard let storage = reservoir.conservationStorage,
                      let capacity = reservoir.conservationCapacity,
                      capacity > 0 else {
                    return nil
                }
                return (storage, capacity)
            }
            if !paired.isEmpty {
                let storage = paired.reduce(0) { $0 + $1.storage }
                let capacity = paired.reduce(0) { $0 + $1.capacity }
                if capacity > 0 { return storage / capacity * 100 }
            }

            let knownPercentages = reservoirs.compactMap(\.percentFull)
            guard !knownPercentages.isEmpty else { return nil }
            return knownPercentages.reduce(0, +) / Double(knownPercentages.count)
        }

        private static func color(for status: ReservoirStatus) -> UIColor {
            switch status {
            case .nearFull: return .systemBlue
            case .normal: return .systemTeal
            case .low: return .systemOrange
            case .critical: return .systemRed
            case .unavailable: return .systemGray
            }
        }

        private static func symbol(for status: ReservoirStatus) -> String {
            switch status {
            case .nearFull: return "drop.fill"
            case .normal: return "drop.halffull"
            case .low: return "drop"
            case .critical: return "exclamationmark.triangle.fill"
            case .unavailable: return "questionmark.circle"
            }
        }

        private static func color(for category: String?) -> UIColor {
            switch category {
            case "D4": return .systemPurple
            case "D3": return .systemRed
            case "D2": return .systemOrange
            case "D1": return .systemYellow
            case "D0": return .systemTeal
            default: return .systemBlue
            }
        }
    }
}

private final class ReservoirAnnotation: NSObject, MKAnnotation {
    let reservoir: ReservoirSummary
    let coordinate: CLLocationCoordinate2D

    var title: String? { reservoir.shortName }

    init(_ reservoir: ReservoirSummary) {
        self.reservoir = reservoir
        coordinate = CLLocationCoordinate2D(latitude: reservoir.latitude, longitude: reservoir.longitude)
    }
}

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
                Text("Shaded areas show the full drought footprint. Labels identify each category.")
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
