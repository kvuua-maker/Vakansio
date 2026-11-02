import SwiftUI
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushManager.shared.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs registration failed: \(error.localizedDescription)")
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

final class PushManager {
    static let shared = PushManager()

    private let tokenKey = "vk.apnsToken"
    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("Push permission error: \(error.localizedDescription)")
            }
            guard granted else { return }

            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func didRegister(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        guard !token.isEmpty else { return }

        UserDefaults.standard.set(token, forKey: tokenKey)
        send(token: token)
    }

    func sendStoredTokenIfNeeded() {
        guard let token = UserDefaults.standard.string(forKey: tokenKey), !token.isEmpty else { return }
        send(token: token)
    }

    private func send(token: String) {
        guard let userId = UserDefaults.standard.string(forKey: "vk.userId"), !userId.isEmpty else {
            return
        }

        Task {
            try? await APIClient.shared.registerDevice(userId: userId, token: token)
        }
    }
}
