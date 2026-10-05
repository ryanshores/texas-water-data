import MapKit
import SwiftUI
import TexasWaterCore

struct DroughtMapView: UIViewRepresentable {
    let areas: [DroughtMapArea]

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
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations)

        let polygons = areas.flatMap { makePolygons(for: $0) }
        map.addOverlays(polygons)
        map.addAnnotations(areas.compactMap(makeAnnotation))

        let rect = polygons.map(\.boundingMapRect).reduce(MKMapRect.null) { $0.union($1) }
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

    private func makeAnnotation(for area: DroughtMapArea) -> MKPointAnnotation? {
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
