import ActivityKit

struct StreetJourneyAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var streetName: String
        var factSnippet: String?
        var streetsVisited: Int
        var neighborhood: String?
    }
}
