import ActivityKit

/// Shared between the main app target and the StreetHistoryWidgets extension.
/// Add this file to both targets in Xcode (File Inspector → Target Membership).
struct StreetJourneyAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var streetName: String
        var factSnippet: String?
        var streetsVisited: Int
        var neighborhood: String?
    }
}
