import SwiftUI
import MapKit

/// Annotation that carries the fact so taps can surface it.
final class FactAnnotation: NSObject, MKAnnotation {
    let fact: FactMapItem
    var coordinate: CLLocationCoordinate2D { fact.coordinate }
    var title: String? { fact.street_name.capitalized }

    init(fact: FactMapItem) { self.fact = fact }
}

/// Polyline that remembers which street it belongs to.
final class StreetPolyline: MKPolyline {
    var confidence: Double = 0.8
    var key: String = ""
}

/// UIKit map. MapKit renders overlays natively and recycles annotation views,
/// so this handles hundreds of street lines that SwiftUI's Map cannot.
struct StreetMapView: UIViewRepresentable {
    var lines: [StreetLine]
    var facts: [FactMapItem]
    var cameraTarget: MKCoordinateRegion?
    var onSelect: (FactMapItem) -> Void
    var onRegionChange: (MKCoordinateRegion) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.pointOfInterestFilter = .excludingAll
        map.register(MKMarkerAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: Coordinator.reuseID)
        map.register(MKMarkerAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        if let target = cameraTarget {
            map.setRegion(target, animated: false)
            context.coordinator.lastApplied = target
        }
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.syncOverlays(map, lines: lines)
        context.coordinator.syncAnnotations(map, facts: facts)

        if let target = cameraTarget, !context.coordinator.matchesLastApplied(target) {
            context.coordinator.lastApplied = target
            map.setRegion(target, animated: true)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        static let reuseID = "factPin"
        var parent: StreetMapView
        var lastApplied: MKCoordinateRegion?
        private var overlayKeys = Set<String>()
        private var annotationKeys = Set<String>()

        init(_ parent: StreetMapView) { self.parent = parent }

        func matchesLastApplied(_ r: MKCoordinateRegion) -> Bool {
            guard let l = lastApplied else { return false }
            return abs(l.center.latitude - r.center.latitude) < 0.000001
                && abs(l.center.longitude - r.center.longitude) < 0.000001
                && abs(l.span.latitudeDelta - r.span.latitudeDelta) < 0.000001
        }

        /// Add/remove only what changed rather than rebuilding every frame.
        func syncOverlays(_ map: MKMapView, lines: [StreetLine]) {
            let incoming = Dictionary(lines.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            let newKeys = Set(incoming.keys)
            guard newKeys != overlayKeys else { return }

            let stale = map.overlays.compactMap { $0 as? StreetPolyline }.filter { !newKeys.contains($0.key) }
            if !stale.isEmpty { map.removeOverlays(stale) }

            let toAdd = newKeys.subtracting(overlayKeys)
            var added: [StreetPolyline] = []
            for key in toAdd {
                guard let line = incoming[key] else { continue }
                var coords = line.coordinates
                guard coords.count >= 2 else { continue }
                let poly = StreetPolyline(coordinates: &coords, count: coords.count)
                poly.confidence = line.confidence
                poly.key = key
                added.append(poly)
            }
            if !added.isEmpty { map.addOverlays(added) }
            overlayKeys = newKeys
        }

        func syncAnnotations(_ map: MKMapView, facts: [FactMapItem]) {
            let incoming = Dictionary(facts.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            let newKeys = Set(incoming.keys)
            guard newKeys != annotationKeys else { return }

            let stale = map.annotations.compactMap { $0 as? FactAnnotation }
                .filter { !newKeys.contains($0.fact.id) }
            if !stale.isEmpty { map.removeAnnotations(stale) }

            let toAdd = newKeys.subtracting(annotationKeys).compactMap { incoming[$0] }
            if !toAdd.isEmpty { map.addAnnotations(toAdd.map(FactAnnotation.init)) }
            annotationKeys = newKeys
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let street = overlay as? StreetPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let r = MKPolylineRenderer(polyline: street)
            r.strokeColor = Self.color(for: street.confidence).withAlphaComponent(0.9)
            r.lineWidth = 5
            r.lineCap = .round
            r.lineJoin = .round
            return r
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let fact = annotation as? FactAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: Self.reuseID, for: annotation) as? MKMarkerAnnotationView
            view?.markerTintColor = Self.color(for: fact.fact.confidence)
            view?.glyphImage = UIImage(systemName: "signpost.right.fill")
            view?.displayPriority = .defaultLow
            view?.clusteringIdentifier = "storiedStreet"
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let fact = (view.annotation as? FactAnnotation)?.fact {
                parent.onSelect(fact)
                mapView.deselectAnnotation(view.annotation, animated: false)
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.onRegionChange(mapView.region)
        }

        static func color(for confidence: Double) -> UIColor {
            if confidence >= 0.85 { return UIColor(red: 0.13, green: 0.42, blue: 0.29, alpha: 1) }
            if confidence >= 0.7 { return UIColor(red: 0.40, green: 0.24, blue: 0.14, alpha: 1) }
            return UIColor(red: 0.55, green: 0.45, blue: 0.25, alpha: 1)
        }
    }
}
