import SwiftUI

struct JourneyHistoryTab: View {
    @ObservedObject var journeyStore: JourneyStore

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            Group {
                if journeyStore.sessions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "figure.walk.circle")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(Color(red: 0.40, green: 0.24, blue: 0.14).opacity(0.5))
                        Text("No walks yet")
                            .font(.title3.weight(.bold))
                        Text("Walk around NYC and the app will log the named streets you visit.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0.92, green: 0.89, blue: 0.84).ignoresSafeArea())
                } else {
                    List {
                        ForEach(journeyStore.sessions) { session in
                            Section {
                                ForEach(session.visits) { visit in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(visit.streetName)
                                            .font(.headline)
                                        Text(dateFormatter.string(from: visit.timestamp))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if let cross = visit.crossStreet, !cross.isEmpty {
                                            Text("Near \(cross)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        if let fact = visit.factSnippet, !fact.isEmpty {
                                            Text(fact)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(3)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            } header: {
                                Text(sessionTitle(session))
                                    .font(.footnote.weight(.semibold))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Walks")
            .toolbar {
                if !journeyStore.sessions.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear", role: .destructive) {
                            journeyStore.clearHistory()
                        }
                    }
                }
            }
        }
    }

    private func sessionTitle(_ session: WalkSession) -> String {
        let start = dateFormatter.string(from: session.startedAt)
        if let end = session.endedAt {
            let duration = Int(end.timeIntervalSince(session.startedAt) / 60)
            return "\(start) · \(duration)m · \(session.visits.count) streets"
        }
        return start
    }
}
