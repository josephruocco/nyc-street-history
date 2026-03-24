import Foundation
import Combine
import CoreLocation

@MainActor
final class CardViewModel: ObservableObject {
    @Published var card: CardResponse?
    @Published var errorText: String?
    @Published var lastUpdatedAt: Date?

    private let api = APIClient()
    private var lastFetchTime: Date = .distantPast

    private let cacheKey = "last_card_v2"

    init() {
        // Load cached card on startup
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode(CardResponse.self, from: data) {
            self.card = cached
        }
    }

    var lastUpdatedText: String? {
        guard let lastUpdatedAt else { return nil }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Updated \(formatter.localizedString(for: lastUpdatedAt, relativeTo: Date()))"
    }

    func update(for location: CLLocation) async {
        let now = Date()
        if now.timeIntervalSince(lastFetchTime) < 2.0 { return }
        lastFetchTime = now

        let acc = max(location.horizontalAccuracy, 10)
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        do {
            let res = try await api.fetchCard(lat: lat, lon: lon, acc: acc)
            card = res
            errorText = nil
            lastUpdatedAt = now
            persist(res)
        } catch {
            guard !Task.isCancelled else { return }

            // Server may be cold-starting (Render free tier). Retry once after a short delay.
            errorText = "Server is warming up, retrying…"
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }

            do {
                let res = try await api.fetchCard(lat: lat, lon: lon, acc: acc)
                card = res
                errorText = nil
                lastUpdatedAt = Date()
                persist(res)
            } catch {
                guard !Task.isCancelled else { return }
                errorText = "Could not reach server. Move around or check your connection."
            }
        }
    }

    private func persist(_ card: CardResponse) {
        if let data = try? JSONEncoder().encode(card) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}
