import SwiftUI

struct NeighborhoodGuide: Identifiable, Hashable {
    let neighborhood: String
    let borough: String
    let summary: String
    let streets: [String]

    var id: String { "\(borough)|\(neighborhood)" }
}

struct BoroughGuide: Identifiable {
    let borough: String
    let neighborhoods: [NeighborhoodGuide]

    var id: String { borough }
}

enum NeighborhoodGuideStore {
    static let boroughs: [BoroughGuide] = [
        BoroughGuide(
            borough: "Manhattan",
            neighborhoods: [
                NeighborhoodGuide(
                    neighborhood: "Lower East Side",
                    borough: "Manhattan",
                    summary: "Dense old Manhattan grid with estate names, immigrant corridors, and some of the city's strongest street-name history.",
                    streets: ["Delancey Street", "Chrystie Street", "Essex Street", "Orchard Street", "Ludlow Street", "Allen Street", "Rivington Street", "Stanton Street", "Norfolk Street", "Suffolk Street", "Clinton Street"]
                ),
                NeighborhoodGuide(
                    neighborhood: "East Village",
                    borough: "Manhattan",
                    summary: "A mix of old named streets and the alphabet avenues, where the grid itself becomes part of the story.",
                    streets: ["Stuyvesant Street", "Avenue A", "Avenue B", "Avenue C", "Avenue D", "Houston Street", "Tompkins Square Park"]
                ),
                NeighborhoodGuide(
                    neighborhood: "Chinatown",
                    borough: "Manhattan",
                    summary: "Older lower-Manhattan street names layered with later immigrant commercial history.",
                    streets: ["Mott Street", "Mulberry Street", "Canal Street", "Bayard Street", "Doyers Street"]
                ),
                NeighborhoodGuide(
                    neighborhood: "SoHo",
                    borough: "Manhattan",
                    summary: "A smaller concentration of named streets with stronger individual namesake stories and cast-iron city history.",
                    streets: ["Mercer Street", "Greene Street", "Wooster Street", "Broome Street", "Spring Street", "Prince Street"]
                ),
                NeighborhoodGuide(
                    neighborhood: "Tribeca",
                    borough: "Manhattan",
                    summary: "Short blocks packed with old family names, mercantile routes, and lower-Manhattan street remnants.",
                    streets: ["Chambers Street", "Reade Street", "Duane Street", "Worth Street", "Hudson Street", "Greenwich Street", "West Broadway"]
                ),
                NeighborhoodGuide(
                    neighborhood: "Civic Center",
                    borough: "Manhattan",
                    summary: "The legal-administrative core of Manhattan, where named streets sit inside a dense institutional landscape.",
                    streets: ["Chambers Street", "Centre Street", "Pearl Street", "Beekman Street", "Park Row", "City Hall Park"]
                ),
                NeighborhoodGuide(
                    neighborhood: "Financial District",
                    borough: "Manhattan",
                    summary: "The oldest layer of Manhattan street naming, where shoreline, commerce, and colonial power remain on the map.",
                    streets: ["Wall Street", "Pearl Street", "Maiden Lane", "Beekman Street", "Broad Street", "Stone Street", "Fulton Street"]
                ),
                NeighborhoodGuide(
                    neighborhood: "Greenwich Village",
                    borough: "Manhattan",
                    summary: "A pre-grid village street pattern where names, bends, and older routes survive more visibly than in midtown.",
                    streets: ["Bleecker Street", "MacDougal Street", "Christopher Street", "Hudson Street", "Waverly Place", "Washington Square Park"]
                )
            ]
        ),
        BoroughGuide(
            borough: "Brooklyn",
            neighborhoods: [
                NeighborhoodGuide(
                    neighborhood: "Williamsburg",
                    borough: "Brooklyn",
                    summary: "One of the best places to walk for named streets in north Brooklyn, with merchants, ferries, industrial families, and old grid history all mixed together.",
                    streets: ["Withers Street", "Bedford Avenue", "Lorimer Street", "Graham Avenue", "Metropolitan Avenue", "Wythe Avenue", "Kent Avenue", "Berry Street", "Roebling Street", "Havemeyer Street", "Keap Street", "Hewes Street"]
                ),
                NeighborhoodGuide(
                    neighborhood: "Greenpoint",
                    borough: "Brooklyn",
                    summary: "A strong waterfront grid of family names, trade names, and industrial-era north Brooklyn history.",
                    streets: ["Nassau Avenue", "Manhattan Avenue", "Franklin Street", "Greenpoint Avenue", "Calyer Street", "Meserole Avenue", "India Street", "Java Street", "Dupont Street", "Norman Avenue", "Monitor Street", "Kingsland Avenue", "Eckford Street"]
                ),
                NeighborhoodGuide(
                    neighborhood: "Downtown Brooklyn",
                    borough: "Brooklyn",
                    summary: "Brooklyn's old civic center, where court, ferry, and founder-era names are packed into a short walk.",
                    streets: ["Jay Street", "Court Street", "Smith Street", "Atlantic Avenue", "Old Fulton Street", "Borough Hall", "Cadman Plaza Park"]
                ),
                NeighborhoodGuide(
                    neighborhood: "Brooklyn Heights",
                    borough: "Brooklyn",
                    summary: "A quieter historic district where civic and waterfront history meet one of Brooklyn's oldest residential areas.",
                    streets: ["Montague Street", "Joralemon Street", "Pierrepont Street", "Hicks Street", "Henry Street", "Brooklyn Heights Promenade"]
                ),
                NeighborhoodGuide(
                    neighborhood: "DUMBO",
                    borough: "Brooklyn",
                    summary: "A former industrial waterfront where old ferry and warehouse-era street names survive inside redevelopment.",
                    streets: ["Water Street", "Front Street", "Old Fulton Street", "Jay Street", "Washington Street", "Dock Street"]
                ),
                NeighborhoodGuide(
                    neighborhood: "Boerum Hill",
                    borough: "Brooklyn",
                    summary: "A neighborhood where Brooklyn's family-name streets and civic corridors become easy to read on foot.",
                    streets: ["Smith Street", "Hoyt Street", "Bond Street", "Wyckoff Street", "Atlantic Avenue", "Court Street"]
                ),
                NeighborhoodGuide(
                    neighborhood: "Bushwick",
                    borough: "Brooklyn",
                    summary: "A deeper inland grid of old family names, brewery history, and industrial-era connectors.",
                    streets: ["DeBevoise Avenue", "Knickerbocker Avenue", "Flushing Avenue", "Bushwick Avenue", "Cooper Park", "Morgan Avenue"]
                )
            ]
        )
    ]

    static func neighborhood(named name: String) -> NeighborhoodGuide? {
        boroughs
            .flatMap(\.neighborhoods)
            .first { $0.neighborhood.caseInsensitiveCompare(name) == .orderedSame }
    }
}

struct NeighborhoodGuideBrowserView: View {
    var body: some View {
        NavigationStack {
            List {
                ForEach(NeighborhoodGuideStore.boroughs) { boroughGuide in
                    Section(boroughGuide.borough) {
                        ForEach(boroughGuide.neighborhoods) { guide in
                            NavigationLink {
                                NeighborhoodGuideDetailView(guide: guide)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(guide.neighborhood)
                                        .font(.headline)
                                    Text(guide.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Named Streets")
        }
    }
}

struct NeighborhoodGuideDetailView: View {
    let guide: NeighborhoodGuide
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(guide.neighborhood)
                            .font(.system(size: 34, weight: .black, design: .rounded))
                        Text(guide.borough)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(red: 0.40, green: 0.24, blue: 0.14))
                        Text(guide.summary)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Named streets to explore")
                            .font(.headline.weight(.bold))

                        ForEach(guide.streets, id: \.self) { street in
                            HStack(alignment: .top, spacing: 10) {
                                Text("•")
                                    .font(.body.weight(.bold))
                                Text(street)
                                    .font(.body)
                            }
                        }
                    }
                    .padding(18)
                    .background(Color(red: 0.95, green: 0.92, blue: 0.84), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .padding(20)
            }
            .background(Color(red: 0.92, green: 0.89, blue: 0.84).ignoresSafeArea())
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
