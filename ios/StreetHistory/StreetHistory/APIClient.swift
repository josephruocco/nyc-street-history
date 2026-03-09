import Foundation

final class APIClient {
    // Simulator: backend on the same Mac
    // Real device: use your Mac LAN IP, e.g. http://192.168.1.50:8000
    private let baseURL = "http://127.0.0.1:8000"

    func fetchCard(lat: Double, lon: Double, acc: Double) async throws -> CardResponse {
        var comps = URLComponents(string: "\(baseURL)/v1/card")!
        comps.queryItems = [
            .init(name: "lat", value: "\(lat)"),
            .init(name: "lon", value: "\(lon)"),
            .init(name: "acc", value: "\(acc)")
        ]
        let url = comps.url!

        let (data, resp) = try await URLSession.shared.data(from: url)
        let http = resp as! HTTPURLResponse
        guard (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(CardResponse.self, from: data)
    }
}
