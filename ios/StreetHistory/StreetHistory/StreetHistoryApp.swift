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

    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem {
                        Label("Street", systemImage: "text.book.closed")
                    }

                FactMapView()
                    .tabItem {
                        Label("Map", systemImage: "map")
                    }
            }
            .tint(Color(red: 0.40, green: 0.24, blue: 0.14))
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
