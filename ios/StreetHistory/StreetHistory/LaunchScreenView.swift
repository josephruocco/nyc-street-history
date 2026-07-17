import SwiftUI

struct LaunchScreenView: View {
    // Cream to match the app icon background (#FBEEDC)
    private let cream = Color(red: 0.984, green: 0.933, blue: 0.863)

    var body: some View {
        ZStack {
            cream.ignoresSafeArea()
            // The exact app icon, presented as a rounded icon splash.
            Image("LaunchIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 8)
        }
    }
}
