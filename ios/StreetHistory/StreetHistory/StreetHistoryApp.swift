import SwiftUI
import UserNotifications

final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

@main
struct StreetHistoryApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var journeyStore = JourneyStore()
    @State private var showLaunch = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                TabView {
                    ContentView(journeyStore: journeyStore)
                        .tabItem {
                            Label("Street", systemImage: "text.book.closed")
                        }

                    FactMapView()
                        .tabItem {
                            Label("Map", systemImage: "map")
                        }

                    FavoritesView(journeyStore: journeyStore)
                        .tabItem {
                            Label("Favorites", systemImage: "heart")
                        }
                }
                .tint(Color(red: 0.40, green: 0.24, blue: 0.14))

                if showLaunch {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        showLaunch = false
                    }
                }
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    let notificationDelegate = AppNotificationDelegate()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        return true
    }
}
