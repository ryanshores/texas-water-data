import SwiftUI
import UIKit
import UserNotifications

extension Notification.Name {
    static let openTexasWaterURL = Notification.Name("openTexasWaterURL")
}

final class TexasWaterAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let rawURL = response.notification.request.content.userInfo["url"] as? String,
              let url = URL(string: rawURL) else {
            return
        }
        NotificationCenter.default.post(name: .openTexasWaterURL, object: url)
    }
}

@main
struct TexasWaterApp: App {
    @UIApplicationDelegateAdaptor(TexasWaterAppDelegate.self) private var appDelegate
    init() {
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .foregroundColor: UIColor.label
        ]
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
