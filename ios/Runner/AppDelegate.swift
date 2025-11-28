import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure Firebase
    FirebaseApp.configure()

    // Set FCM messaging delegate
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      Messaging.messaging().delegate = self
    }

    GeneratedPluginRegistrant.register(with: self)

    // Request notification authorization
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
        if granted {
          print("✅ Notification permission granted")
        } else {
          print("⚠️ Notification permission denied")
        }
      }
    }

    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle registration for remote notifications
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
    print("📱 APNs device token: \(deviceToken)")
  }

  // Handle failure to register for remote notifications
  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ Failed to register for remote notifications: \(error)")
  }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    if let token = fcmToken {
      print("🔥 FCM registration token: \(token)")
      // Token will be handled by Flutter side
    }
  }
}
