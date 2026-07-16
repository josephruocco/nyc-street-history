import Foundation
import CoreLocation
import Combine

/// A developer/demo override: when a coordinate is set, the app pretends you're
/// standing there instead of using GPS. Lets you see any street's card from
/// anywhere. Shared singleton so Settings and LocationManager stay in sync.
@MainActor
final class DemoLocationStore: ObservableObject {
    static let shared = DemoLocationStore()

    struct Preset: Identifiable, Hashable {
        var id: String { name }
        let name: String
        let lat: Double
        let lon: Double
        var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lon) }
    }

    /// A spread across the boroughs, including recently added streets.
    let presets: [Preset] = [
        .init(name: "Humboldt Street", lat: 40.72832, lon: -73.94589),
        .init(name: "Bedford Avenue", lat: 40.70563, lon: -73.96279),
        .init(name: "Wall Street", lat: 40.70578, lon: -74.00894),
        .init(name: "Amsterdam Avenue", lat: 40.81542, lon: -73.95477),
        .init(name: "Dyckman Street", lat: 40.86405, lon: -73.92632),
        .init(name: "Astoria Boulevard", lat: 40.76173, lon: -73.86776),
        .init(name: "Queens Boulevard", lat: 40.72863, lon: -73.85826),
        .init(name: "Fort Hamilton Parkway", lat: 40.62701, lon: -74.01464),
        .init(name: "Victory Boulevard (SI)", lat: 40.58989, lon: -74.19378),
    ]

    @Published var coordinate: CLLocationCoordinate2D?
    @Published var activeName: String?

    private let latKey = "demo_lat"
    private let lonKey = "demo_lon"
    private let nameKey = "demo_name"

    private init() {
        let d = UserDefaults.standard
        if d.object(forKey: latKey) != nil {
            coordinate = .init(latitude: d.double(forKey: latKey), longitude: d.double(forKey: lonKey))
            activeName = d.string(forKey: nameKey)
        }
    }

    func set(_ preset: Preset) {
        coordinate = preset.coordinate
        activeName = preset.name
        let d = UserDefaults.standard
        d.set(preset.lat, forKey: latKey)
        d.set(preset.lon, forKey: lonKey)
        d.set(preset.name, forKey: nameKey)
    }

    func clear() {
        coordinate = nil
        activeName = nil
        let d = UserDefaults.standard
        d.removeObject(forKey: latKey)
        d.removeObject(forKey: lonKey)
        d.removeObject(forKey: nameKey)
    }
}
