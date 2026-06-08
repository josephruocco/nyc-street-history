import SwiftUI
import MapKit
import Combine

struct FactMapItem: Codable, Identifiable, Hashable {
    var id: String { street_name }
    let street_name: String
    let fact_text: String
    let namesake: String?
    let source_label: String?
    let source_url: String?
    let confidence: Double
    let lat: Double
    let lon: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

@MainActor
final class FactMapViewModel: ObservableObject {
    @Published var facts: [FactMapItem] = []
    @Published var isLoading = false
    @Published var errorText: String?

    private let baseURL: String
    private static let cacheKey = "cachedMapFacts"
    private static let cacheTimestampKey = "cachedMapFactsTimestamp"
    private static let cacheTTL: TimeInterval = 3600 // 1 hour

    init() {
        self.baseURL = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String
            ?? "https://nyc-street-history.onrender.com"
    }

    func load() async {
        guard facts.isEmpty else { return }

        // Try loading from disk cache first
        if let cached = loadFromCache() {
            facts = cached
            // Refresh in background if cache is older than TTL
            if isCacheStale() {
                Task { await fetchAndCache() }
            }
            return
        }

        // No cache — fetch from network
        isLoading = true
        errorText = nil
        await fetchAndCache()
        isLoading = false
    }

    private func fetchAndCache() async {
        do {
            var comps = URLComponents(string: "\(baseURL)/v1/facts/map")!
            comps.queryItems = [.init(name: "min_confidence", value: "0.0")]
            let (data, resp) = try await URLSession.shared.data(from: comps.url!)
            let http = resp as! HTTPURLResponse
            guard (200..<300).contains(http.statusCode) else {
                if facts.isEmpty { errorText = "Server error (\(http.statusCode))" }
                return
            }
            let decoded = try JSONDecoder().decode([FactMapItem].self, from: data)
            facts = decoded
            saveToCache(data)
        } catch {
            if facts.isEmpty { errorText = error.localizedDescription }
        }
    }

    private func saveToCache(_ data: Data) {
        UserDefaults.standard.set(data, forKey: Self.cacheKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.cacheTimestampKey)
    }

    private func loadFromCache() -> [FactMapItem]? {
        guard let data = UserDefaults.standard.data(forKey: Self.cacheKey) else { return nil }
        return try? JSONDecoder().decode([FactMapItem].self, from: data)
    }

    private func isCacheStale() -> Bool {
        let ts = UserDefaults.standard.double(forKey: Self.cacheTimestampKey)
        guard ts > 0 else { return true }
        return Date().timeIntervalSince1970 - ts > Self.cacheTTL
    }
}

struct FactMapView: View {
    @StateObject private var vm = FactMapViewModel()
    @State private var selectedFact: FactMapItem?
    @State private var searchText = ""
    @State private var showSearch = false
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.6782, longitude: -73.9442),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )

    private var searchResults: [FactMapItem] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return vm.facts.filter { $0.street_name.lowercased().contains(query) }
    }

    var body: some View {
        ZStack {
            Map(position: $position) {
                UserAnnotation()

                ForEach(vm.facts) { fact in
                    Annotation(prettifyStreetName(fact.street_name), coordinate: fact.coordinate) {
                        Button {
                            selectedFact = fact
                        } label: {
                            Circle()
                                .fill(markerColor(fact.confidence))
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                .shadow(radius: 2)
                        }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    factCountBadge

                    Spacer()

                    Button {
                        withAnimation { showSearch.toggle() }
                        if !showSearch { searchText = "" }
                    } label: {
                        Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                            .font(.caption.weight(.bold))
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }

                    Button {
                        position = .userLocation(fallback: .automatic)
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.caption.weight(.bold))
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if showSearch {
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Search streets…", text: $searchText)
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled()
                        }
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        if !searchResults.isEmpty {
                            ScrollView {
                                VStack(spacing: 2) {
                                    ForEach(searchResults.prefix(8)) { fact in
                                        Button {
                                            selectedFact = fact
                                            position = .region(MKCoordinateRegion(
                                                center: fact.coordinate,
                                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                            ))
                                            showSearch = false
                                            searchText = ""
                                        } label: {
                                            HStack {
                                                Circle()
                                                    .fill(markerColor(fact.confidence))
                                                    .frame(width: 8, height: 8)
                                                Text(prettifyStreetName(fact.street_name))
                                                    .font(.subheadline.weight(.medium))
                                                    .foregroundStyle(Color.primary)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                        }
                                    }
                                }
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                                .padding(.horizontal, 16)
                                .padding(.top, 4)
                            }
                            .frame(maxHeight: 300)
                        }
                    }
                }

                Spacer()

                if let fact = selectedFact {
                    factCard(fact)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: selectedFact?.id)

            if vm.isLoading {
                ProgressView("Loading facts…")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }

            if let error = vm.errorText {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                    Text(error)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .task {
            await vm.load()
        }
    }

    private var factCountBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin.circle.fill")
                .font(.caption.weight(.bold))
            Text("\(vm.facts.count) streets")
                .font(.caption.weight(.bold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func factCard(_ fact: FactMapItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(prettifyStreetName(fact.street_name))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.black.opacity(0.92))

                Spacer()

                Button {
                    selectedFact = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            if let namesake = fact.namesake, !namesake.isEmpty {
                Text("Named for: \(namesake)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.40, green: 0.24, blue: 0.14))
            }

            Text(fact.fact_text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.black.opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                if let source = fact.source_label {
                    Text(source)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                confidencePill(fact.confidence)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private func confidencePill(_ confidence: Double) -> some View {
        let pct = Int(confidence * 100)
        return Text("\(pct)%")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(markerColor(confidence).opacity(0.15), in: Capsule())
            .foregroundStyle(markerColor(confidence))
    }

    private func markerColor(_ confidence: Double) -> Color {
        if confidence >= 0.85 {
            return Color(red: 0.21, green: 0.46, blue: 0.27)
        } else if confidence >= 0.65 {
            return Color(red: 0.50, green: 0.33, blue: 0.11)
        } else {
            return Color(red: 0.61, green: 0.24, blue: 0.19)
        }
    }

    private func prettifyStreetName(_ name: String) -> String {
        name.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
