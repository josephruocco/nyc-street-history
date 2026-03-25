import WidgetKit
import SwiftUI

// MARK: - Timeline

struct StreetCardEntry: TimelineEntry {
    let date: Date
    let card: SharedStreetCard?
}

struct StreetCardProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreetCardEntry {
        StreetCardEntry(date: Date(), card: SharedStreetCard(
            streetName: "Delancey Street",
            neighborhood: "Lower East Side",
            borough: "Manhattan",
            factSnippet: "Named for James De Lancey, a powerful colonial landowner whose family estate once covered much of the Lower East Side.",
            namesake: "James De Lancey",
            updatedAt: Date()
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (StreetCardEntry) -> Void) {
        completion(StreetCardEntry(date: Date(), card: SharedStreetCard.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreetCardEntry>) -> Void) {
        let entry = StreetCardEntry(date: Date(), card: SharedStreetCard.load())
        // Never auto-refresh — the main app pushes updates via WidgetCenter.reloadAllTimelines()
        completion(Timeline(entries: [entry], policy: .never))
    }
}

// MARK: - Colors

private let cream = Color(red: 0.985, green: 0.975, blue: 0.95)
private let brown = Color(red: 0.40, green: 0.24, blue: 0.14)
private let softBrown = Color(red: 0.55, green: 0.38, blue: 0.26)

// MARK: - Home screen widget views

struct StreetWidgetSmallView: View {
    let entry: StreetCardEntry

    var body: some View {
        if let card = entry.card {
            VStack(alignment: .leading, spacing: 6) {
                Text(card.streetName)
                    .font(.headline.weight(.black))
                    .foregroundStyle(brown)
                    .lineLimit(2)

                if let fact = card.factSnippet, !fact.isEmpty {
                    Text(fact)
                        .font(.caption2)
                        .foregroundStyle(softBrown)
                        .lineLimit(4)
                }

                Spacer(minLength: 0)

                if let hood = card.neighborhood {
                    Text(hood.uppercased())
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(brown.opacity(0.5))
                        .lineLimit(1)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(cream)
        } else {
            emptyState
        }
    }
}

struct StreetWidgetMediumView: View {
    let entry: StreetCardEntry

    var body: some View {
        if let card = entry.card {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(card.streetName)
                        .font(.title3.weight(.black))
                        .foregroundStyle(brown)
                        .lineLimit(2)

                    if let namesake = card.namesake, !namesake.isEmpty {
                        Text("Named for \(namesake)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(softBrown)
                    }

                    Spacer(minLength: 0)

                    if let hood = card.neighborhood {
                        Text(hood.uppercased())
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(brown.opacity(0.5))
                    }
                }

                if let fact = card.factSnippet, !fact.isEmpty {
                    Text(fact)
                        .font(.caption2)
                        .foregroundStyle(softBrown)
                        .lineLimit(6)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(cream)
        } else {
            emptyState
        }
    }
}

// MARK: - Lock screen widget views

struct StreetLockRectangularView: View {
    let entry: StreetCardEntry

    var body: some View {
        if let card = entry.card {
            VStack(alignment: .leading, spacing: 2) {
                Text(card.streetName)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                if let fact = card.factSnippet, !fact.isEmpty {
                    Text(fact)
                        .font(.system(size: 10))
                        .lineLimit(2)
                        .opacity(0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("Open StreetHistory")
                .font(.caption)
        }
    }
}

struct StreetLockInlineView: View {
    let entry: StreetCardEntry

    var body: some View {
        if let card = entry.card {
            Text(card.streetName)
        } else {
            Text("StreetHistory")
        }
    }
}

struct StreetLockCircularView: View {
    let entry: StreetCardEntry

    var body: some View {
        if let card = entry.card {
            VStack(spacing: 1) {
                Image(systemName: "mappin")
                    .font(.system(size: 10, weight: .bold))
                Text(card.streetName.components(separatedBy: " ").first ?? "")
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        } else {
            Image(systemName: "mappin")
        }
    }
}

// MARK: - Empty state

private var emptyState: some View {
    VStack(spacing: 6) {
        Image(systemName: "mappin.slash")
            .font(.title3)
            .foregroundStyle(brown.opacity(0.4))
        Text("Walk past a named street")
            .font(.caption2)
            .foregroundStyle(brown.opacity(0.5))
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(cream)
}

// MARK: - Widget definition

struct StreetHistoryWidget: Widget {
    let kind = "StreetHistoryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreetCardProvider()) { entry in
            StreetHistoryWidgetEntryView(entry: entry)
                .containerBackground(cream, for: .widget)
        }
        .configurationDisplayName("Street History")
        .description("See the history of the last named street you walked past.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCircular,
        ])
    }
}

struct StreetHistoryWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: StreetCardEntry

    var body: some View {
        switch family {
        case .systemSmall:
            StreetWidgetSmallView(entry: entry)
        case .systemMedium:
            StreetWidgetMediumView(entry: entry)
        case .accessoryRectangular:
            StreetLockRectangularView(entry: entry)
        case .accessoryInline:
            StreetLockInlineView(entry: entry)
        case .accessoryCircular:
            StreetLockCircularView(entry: entry)
        default:
            StreetWidgetSmallView(entry: entry)
        }
    }
}
