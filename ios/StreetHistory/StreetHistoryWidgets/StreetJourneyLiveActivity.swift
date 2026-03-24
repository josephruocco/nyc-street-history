import ActivityKit
import WidgetKit
import SwiftUI

struct StreetJourneyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StreetJourneyAttributes.self) { context in
            // Lock screen / notification banner
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(context.state.streetName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let fact = context.state.factSnippet, !fact.isEmpty {
                        Text(fact)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else if let hood = context.state.neighborhood, !hood.isEmpty {
                        Text(hood)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(spacing: 2) {
                    Image(systemName: "figure.walk")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(red: 0.40, green: 0.24, blue: 0.14))
                    Text("\(context.state.streetsVisited)")
                        .font(.title3.weight(.black))
                        .monospacedDigit()
                        .foregroundStyle(Color(red: 0.40, green: 0.24, blue: 0.14))
                    Text("streets")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .activityBackgroundTint(Color(red: 0.985, green: 0.975, blue: 0.95))
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text("\(context.state.streetsVisited)")
                            .font(.caption.weight(.bold))
                    } icon: {
                        Image(systemName: "figure.walk")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color(red: 0.40, green: 0.24, blue: 0.14))
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.streetName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if let fact = context.state.factSnippet, !fact.isEmpty {
                            Text(fact)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 6)
                }

            } compactLeading: {
                Image(systemName: "figure.walk")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.40, green: 0.24, blue: 0.14))

            } compactTrailing: {
                Text(context.state.streetName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 110)

            } minimal: {
                Image(systemName: "figure.walk")
                    .foregroundStyle(Color(red: 0.40, green: 0.24, blue: 0.14))
            }
            .widgetURL(URL(string: "streethistory://journey"))
            .keylineTint(Color(red: 0.40, green: 0.24, blue: 0.14))
        }
    }
}
