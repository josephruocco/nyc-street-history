import SwiftUI

struct LaunchScreenView: View {
    // Cream to match the app icon background (#FBEEDC)
    private let cream = Color(red: 0.984, green: 0.933, blue: 0.863)

    var body: some View {
        ZStack {
            cream.ignoresSafeArea()
            Image("LaunchSign")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 230)
                .padding(.bottom, 40)
        }
    }
}
