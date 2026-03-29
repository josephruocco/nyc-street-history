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

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(journeyStore)
        }
    }
}

struct RootTabView: View {
    @EnvironmentObject var journeyStore: JourneyStore

    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Street", systemImage: "location.fill")
                }

            StreetMapView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }

            JourneyHistoryTab(journeyStore: journeyStore)
                .tabItem {
                    Label("Walks", systemImage: "figure.walk")
                }
        }
        .tint(Color(red: 0.40, green: 0.24, blue: 0.14))
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
