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
        context.coordinator.mapView = map
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.onSelectReservoir = onSelectReservoir
        guard context.coordinator.droughtAreas != droughtAreas
            || context.coordinator.reservoirs != reservoirs else {
            return
        }
        context.coordinator.droughtAreas = droughtAreas
        context.coordinator.reservoirs = reservoirs

        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations)

        let polygons = droughtAreas.flatMap { makePolygons(for: $0) }
        map.addOverlays(polygons)
        map.addAnnotations(reservoirs.map(ReservoirAnnotation.init))

        var rect = polygons.map(\.boundingMapRect).reduce(MKMapRect.null) { $0.union($1) }
        for reservoir in reservoirs {
            let point = MKMapPoint(CLLocationCoordinate2D(latitude: reservoir.latitude, longitude: reservoir.longitude))
            rect = rect.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
        }
        if !rect.isNull {
            // If the rect is too small (single point case), expand it by a minimum size
            if rect.size.width < 1 && rect.size.height < 1 {
                // Choose a minimum view span (in meters)
                let minMeters: Double = 5_000 // ~5km
                let center = MKMapPoint(x: rect.midX, y: rect.midY)
                let metersPerMapPoint = 1.0 / MKMetersPerMapPointAtLatitude(map.centerCoordinate.latitude)
                let halfWidth = (minMeters * metersPerMapPoint) / 2.0
                let halfHeight = (minMeters * metersPerMapPoint) / 2.0

                rect = MKMapRect(
                    x: center.x - halfWidth,
                    y: center.y - halfHeight,
                    width: halfWidth * 2.0,
                    height: halfHeight * 2.0
                )
            }

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

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onSelectReservoir: (ReservoirSummary) -> Void = { _ in }
        var droughtAreas: [DroughtMapArea]?
        var reservoirs: [ReservoirSummary]?
        weak var mapView: MKMapView?

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
                view.glyphImage = UIImage(systemName: reservoirAnnotation.reservoir.status.systemImage)
                view.glyphText = nil
                view.markerTintColor = reservoirAnnotation.reservoir.status.systemColor
                view.clusteringIdentifier = "reservoirs"
                view.displayPriority = .defaultHigh
                view.titleVisibility = .hidden
                view.subtitleVisibility = .hidden
                view.accessibilityLabel = "\(reservoirAnnotation.reservoir.shortName), \(WaterFormatting.percent(reservoirAnnotation.reservoir.percentFull))"
                return view
            }

            return nil
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
            view.markerTintColor = ReservoirStatus.classify(percentFull: percentFull).systemColor
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
                let point = MKMapPoint(member.coordinate)
                rect = rect.union(MKMapRect(origin: point, size: .init(width: 0, height: 0)))
            }
            guard !rect.isNull else { return }

            // Get usable size (in points)
            let insets = mapView.safeAreaInsets
            let usableWidth = mapView.bounds.width - (insets.left + insets.right)
            let usableHeight = mapView.bounds.height - (insets.top + insets.bottom)

            // Derive padding relative to size
            let xPadding = max(160, usableWidth * 0.15)
            let yPadding = max(120, usableHeight * 0.20)

            mapView.deselectAnnotation(cluster, animated: false)
            mapView.setVisibleMapRect(
                rect,
                edgePadding: UIEdgeInsets(top: yPadding, left: xPadding, bottom: yPadding, right: xPadding),
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
