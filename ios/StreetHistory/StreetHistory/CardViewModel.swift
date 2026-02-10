import Foundation
import Combine
import CoreLocation

@MainActor
final class CardViewModel: ObservableObject {
    @Published var card: CardResponse?
    @Published var errorText: String?

    private let api = APIClient()
    private var lastFetchTime: Date = .distantPast

    private let cacheKey = "last_card_v1"

    init() {
        // Load cached card on startup
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode(CardResponse.self, from: data) {
            self.card = cached
        }
    }

    func update(for location: CLLocation) async {
        let now = Date()
        if now.timeIntervalSince(lastFetchTime) < 2.0 { return }
        lastFetchTime = now

        do {
            let acc = max(location.horizontalAccuracy, 10)
            let res = try await api.fetchCard(
                lat: location.coordinate.latitude,
                lon: location.coordinate.longitude,
                acc: acc
            )
            card = res
            errorText = nil
            persist(res)
        } catch {
            // Keep cached card; show error
            errorText = error.localizedDescription
        }
    }

    private func persist(_ card: CardResponse) {
        if let data = try? JSONEncoder().encode(card) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}
