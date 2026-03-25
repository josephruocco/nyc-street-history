import Foundation

let appGroupID = "group.com.josephruocco.StreetHistory"
let sharedCardKey = "lastStreetCard"

struct SharedStreetCard: Codable {
    var streetName: String
    var neighborhood: String?
    var borough: String?
    var factSnippet: String?
    var namesake: String?
    var updatedAt: Date

    static func load() -> SharedStreetCard? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: sharedCardKey) else { return nil }
        return try? JSONDecoder().decode(SharedStreetCard.self, from: data)
    }

    func save() {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: sharedCardKey)
    }
}
