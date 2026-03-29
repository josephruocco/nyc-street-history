import SwiftUI
import MapKit

struct StreetMapView: View {
    @State private var selectedGuide: NeighborhoodGuide?
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.710, longitude: -73.975),
            span: MKCoordinateSpan(latitudeDelta: 0.14, longitudeDelta: 0.14)
        )
    )

    private var allNeighborhoods: [NeighborhoodGuide] {
        NeighborhoodGuideStore.boroughs.flatMap(\.neighborhoods)
    }

    var body: some View {
        Map(position: $position) {
            UserAnnotation()
            ForEach(allNeighborhoods) { guide in
                Annotation(guide.neighborhood, coordinate: guide.coordinate, anchor: .bottom) {
                    NeighborhoodPin(guide: guide) {
                        selectedGuide = guide
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .ignoresSafeArea(edges: .bottom)
        .sheet(item: $selectedGuide) { guide in
            NeighborhoodGuideDetailView(guide: guide)
        }
    }
}

private struct NeighborhoodPin: View {
    let guide: NeighborhoodGuide
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.40, green: 0.24, blue: 0.14))
                        .frame(width: 34, height: 34)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    Text("\(guide.streets.count)")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white)
                }

                Text(guide.neighborhood)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(red: 0.40, green: 0.24, blue: 0.14))
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.985, green: 0.975, blue: 0.95).opacity(0.95))
                            .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
                    )
            }
        }
        .buttonStyle(.plain)
    }
}
