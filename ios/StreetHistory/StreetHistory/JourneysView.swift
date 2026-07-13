import SwiftUI

struct JourneysView: View {
    @ObservedObject var journeyStore: JourneyStore

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "signpost.right.and.left.fill")
                            .font(.title)
                            .foregroundStyle(Color(red: 0.40, green: 0.24, blue: 0.14))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(journeyStore.streetsExploredCount)")
                                .font(.system(size: 34, weight: .black, design: .rounded))
                            Text(journeyStore.streetsExploredCount == 1 ? "street explored" : "streets explored")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                } footer: {
                    Text("Every named street you pass with the app open counts, journey or not.")
                }

                if journeyStore.isJourneyActive, let session = journeyStore.currentSession {
                    Section("Current walk") {
                        ForEach(session.visits.reversed()) { visit in
                            visitRow(visit)
                        }
                        Button("Stop journey", role: .destructive) {
                            journeyStore.stopJourney()
                        }
                    }
                } else {
                    Section {
                        Button {
                            Task { await journeyStore.startJourney() }
                        } label: {
                            Label("Start a journey", systemImage: "figure.walk")
                        }
                    } footer: {
                        Text("A journey logs each street of one walk as its own trip.")
                    }
                }

                if journeyStore.sessions.isEmpty && !journeyStore.isJourneyActive {
                    Section("Past walks") {
                        Text("No walks logged yet.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(journeyStore.sessions) { session in
                        Section(sessionTitle(session)) {
                            ForEach(session.visits) { visit in
                                visitRow(visit)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Journeys")
            .toolbar {
                if !journeyStore.sessions.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") {
                            journeyStore.clearHistory()
                        }
                    }
                }
            }
        }
    }

    private func visitRow(_ visit: StreetVisit) -> some View {
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
            if let fact = visit.factSnippet, !fact.isEmpty,
               !fact.contains("still being researched") {
                Text(fact)
                    .font(.subheadline)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
    }

    private func sessionTitle(_ session: WalkSession) -> String {
        let start = dateFormatter.string(from: session.startedAt)
        if let endedAt = session.endedAt {
            return "\(start) to \(dateFormatter.string(from: endedAt))"
        }
        return start
    }
}
