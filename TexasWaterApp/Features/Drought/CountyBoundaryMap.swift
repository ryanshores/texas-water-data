import MapKit
import SwiftUI
import TexasWaterCore

struct CountyBoundaryMap: UIViewRepresentable {
    let boundary: DroughtCountyBoundary
    let color: Color

    func makeCoordinator() -> Coordinator {
        Coordinator(color: UIColor(color))
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.isPitchEnabled = false
        map.isRotateEnabled = false
        map.showsCompass = false
        map.showsScale = false
        map.pointOfInterestFilter = .excludingAll
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.color = UIColor(color)
        let polygons = boundary.coordinates.compactMap(makePolygon)
        guard !polygons.isEmpty else { return }
        map.removeOverlays(map.overlays)
        map.addOverlays(polygons)

        let rect = polygons.map(\.boundingMapRect).reduce(MKMapRect.null) { $0.union($1) }
        if !rect.isNull {
            map.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24), animated: false)
        }
    }

    private func makePolygon(_ ring: [[Double]]) -> MKPolygon? {
        var coordinates = ring.compactMap { pair -> CLLocationCoordinate2D? in
            guard pair.count > 1 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
        }
        guard coordinates.count > 2 else { return nil }
        return MKPolygon(coordinates: &coordinates, count: coordinates.count)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var color: UIColor

        init(color: UIColor) {
            self.color = color
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polygon = overlay as? MKPolygon else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.strokeColor = color
            renderer.fillColor = color.withAlphaComponent(0.2)
            renderer.lineWidth = 2
            return renderer
        }
    }
}
