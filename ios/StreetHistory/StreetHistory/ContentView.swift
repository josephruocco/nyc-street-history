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

    private var subtitleLine: String? {
        if let street = vm.card?.canonical_street, !street.isEmpty {
            return "Near \(street)"
        }
        let parts = [vm.card?.neighborhood, vm.card?.borough].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                if !isAuthorized {
                    Button("Enable Location") {
                        lm.requestPermissionAndStart()
                    }
                }

                Spacer()

                if !isAuthorized {
                    Text(statusText(lm.status))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if isUpdating {
                    Text("Updating…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Group {
                if let card = vm.card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(card.canonical_street ?? "Unknown street")
                            .font(.title2).bold()

                        if let sub = subtitleLine {
                            Text(sub)
                                .foregroundStyle(.secondary)
                        }

                        if let dyk = card.did_you_know {
                            Text("Did you know?")
                                .font(.headline)
                                .padding(.top, 6)
                            Text(dyk)
                        }

                        if !card.nearby.isEmpty {
                            Text("Nearby")
                                .font(.headline)
                                .padding(.top, 6)
                            ForEach(card.nearby) { item in
                                Text("• \(item.name) (\(item.category)) – \(item.distance_m)m")
                            }
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                } else {
                    if !isAuthorized {
                        Text("Enable location to get a card.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Loading…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: vm.card?.canonical_street ?? "")

            if let err = vm.errorText {
                Text(err)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.top, 6)
            }

            Spacer()
        }
        .padding()

        // Fetch only when you move ~40m
        .onChange(of: lm.significantLocation) { _, loc in
            guard isAuthorized, let loc else { return }

            isUpdating = true
            fetchTask?.cancel()
            fetchTask = Task {
                defer { isUpdating = false }
                await vm.update(for: loc)
            }
        }

        // Auto-start if already authorized
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
