import SwiftUI
import CoreLocation
import Combine

struct ContentView: View {
    @StateObject private var lm = LocationManager()
    @StateObject private var vm = CardViewModel()

    @State private var fetchTask: Task<Void, Never>?
    @State private var isUpdating = false

    private var isAuthorized: Bool {
        lm.status == .authorizedWhenInUse || lm.status == .authorizedAlways
    }

    private var placeLine: String? {
        let parts = [vm.card?.neighborhood, vm.card?.borough].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private var headerAccent: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.12, green: 0.22, blue: 0.28),
                Color(red: 0.42, green: 0.27, blue: 0.17),
                Color(red: 0.79, green: 0.60, blue: 0.34)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.93, blue: 0.89)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerAccent
                    .frame(height: 220)
                    .blur(radius: 12)
                Spacer()
            }
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    statusBar
                    mainCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }

        .onChange(of: lm.significantLocation) { _, loc in
            guard isAuthorized, let loc else { return }

            isUpdating = true
            fetchTask?.cancel()
            fetchTask = Task {
                defer { isUpdating = false }
                await vm.update(for: loc)
            }
        }
        .onChange(of: lm.status) { _, _ in
            if isAuthorized {
                lm.requestPermissionAndStart()
            }
        }
        .onAppear {
            if isAuthorized {
                lm.requestPermissionAndStart()
            }
        }
    }

    private var statusBar: some View {
        HStack {
            if !isAuthorized {
                Button("Enable Location") {
                    lm.requestPermissionAndStart()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.82), in: Capsule())
                .foregroundStyle(.white)
            } else {
                Label(isUpdating ? "Updating" : "Live", systemImage: isUpdating ? "location.circle.fill" : "dot.radiowaves.left.and.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isUpdating ? Color(red: 0.42, green: 0.27, blue: 0.17) : Color(red: 0.12, green: 0.22, blue: 0.28))
            }

            Spacer()

            if !isAuthorized {
                Text(statusText(lm.status))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let lastUpdated = vm.lastUpdatedText {
                Text(lastUpdated)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 2)
    }

    private var mainCard: some View {
        Group {
            if let card = vm.card {
                VStack(alignment: .leading, spacing: 22) {
                    heroSection(card)
                    factSection(card)
                    nearbySection(card)
                    if let err = vm.errorText {
                        inlineError(err)
                    }
                }
                .padding(22)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color.white.opacity(0.90))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 22, x: 0, y: 14)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
            } else if !isAuthorized {
                emptyState(
                    title: "Turn on location",
                    body: "The app needs your location to match your street to nearby history.",
                    systemImage: "location.slash"
                )
            } else {
                emptyState(
                    title: "Finding your street",
                    body: "Waiting for a stable location update before fetching a card.",
                    systemImage: "location.magnifyingglass"
                )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: vm.card?.canonical_street ?? "")
    }

    private func heroSection(_ card: CardResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let placeLine {
                Text(placeLine.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.3)
                    .foregroundStyle(Color(red: 0.42, green: 0.27, blue: 0.17))
            }

            Text(card.canonical_street ?? "Unknown street")
                .font(.system(size: 40, weight: .heavy, design: .serif))
                .foregroundStyle(Color.black.opacity(0.94))

            HStack(spacing: 10) {
                if let cross = card.cross_street, !cross.isEmpty {
                    labelChip(title: "At", value: cross)
                }
                labelChip(title: "Mode", value: modeLabel(card.mode))
            }

            if let firstPlace = prominentNearbyPlace(card) {
                Text("Near \(firstPlace.name)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func factSection(_ card: CardResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Did you know?")
                .font(.title3.weight(.heavy))

            if let dyk = card.did_you_know, !dyk.isEmpty {
                Text(dyk)
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.9))
                    .lineSpacing(4)
            } else {
                Text("No historical note yet for this spot.")
                    .foregroundStyle(.secondary)
            }

            if let source = card.sources?.first, let label = source.label, !label.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "books.vertical")
                    Text(label)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(red: 0.12, green: 0.22, blue: 0.28))
            }
        }
        .padding(18)
        .background(Color(red: 0.98, green: 0.95, blue: 0.88), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func nearbySection(_ card: CardResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Nearby")
                    .font(.title3.weight(.heavy))
                Spacer()
                Text("\(card.nearby.count) places")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ForEach(uniqueNearby(card.nearby)) { item in
                HStack(alignment: .top, spacing: 14) {
                    Circle()
                        .fill(categoryColor(item.category))
                        .frame(width: 10, height: 10)
                        .padding(.top, 7)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.black.opacity(0.92))

                        HStack(spacing: 8) {
                            Text(prettyCategory(item.category))
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(categoryColor(item.category).opacity(0.14), in: Capsule())
                                .foregroundStyle(categoryColor(item.category))

                            Text(distanceLabel(item.distance_m))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(14)
                .background(Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private func inlineError(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .padding(12)
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func emptyState(title: String, body: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color(red: 0.42, green: 0.27, blue: 0.17))

            Text(title)
                .font(.title2.weight(.heavy))

            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(3)

            if let err = vm.errorText {
                inlineError(err)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.90))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private func labelChip(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.black))
                .tracking(0.9)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.86))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.05), in: Capsule())
    }

    private func categoryColor(_ category: String) -> Color {
        switch category.lowercased() {
        case "park":
            return Color(red: 0.21, green: 0.46, blue: 0.27)
        case "transit":
            return Color(red: 0.17, green: 0.33, blue: 0.58)
        case "food":
            return Color(red: 0.61, green: 0.24, blue: 0.19)
        case "landmark":
            return Color(red: 0.50, green: 0.33, blue: 0.11)
        default:
            return .gray
        }
    }

    private func prettyCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "park":
            return "Park"
        case "transit":
            return "Transit"
        case "food":
            return "Food"
        case "landmark":
            return "Landmark"
        default:
            return category.capitalized
        }
    }

    private func distanceLabel(_ meters: Int) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km away", Double(meters) / 1000.0)
        }
        return "\(meters)m away"
    }

    private func modeLabel(_ mode: String) -> String {
        switch mode {
        case "NAMED_STREET":
            return "Named Street"
        case "NUMBERED_STREET":
            return "Numbered Street"
        default:
            return mode.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func prominentNearbyPlace(_ card: CardResponse) -> NearbyItem? {
        uniqueNearby(card.nearby).first
    }

    private func uniqueNearby(_ items: [NearbyItem]) -> [NearbyItem] {
        var seen = Set<String>()
        var result: [NearbyItem] = []

        for item in items {
            let key = "\(item.name.lowercased())|\(item.category.lowercased())"
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(item)
        }

        return result
    }

    private func statusText(_ s: CLAuthorizationStatus) -> String {
        switch s {
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "notDetermined"
        @unknown default: return "unknown"
        }
    }
}
