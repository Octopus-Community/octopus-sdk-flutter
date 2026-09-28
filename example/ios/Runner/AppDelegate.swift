import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {

  /// Cached cold-start push payload (if the app was launched by tapping a notification).
  /// Drained once Dart calls `getInitialNotification`.
  private var pendingInitialNotification: [AnyHashable: Any]?

  /// MethodChannel used to forward APNs/UN events to Dart and answer cold-start queries.
  private var pushChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Cold-start tap: capture the userInfo so Dart can pull it on startup.
    if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      pendingInitialNotification = userInfo
    }

    // Wire up the push MethodChannel to the Flutter view controller.
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "octopus_sdk_flutter_example/push",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { result(nil); return }
        switch call.method {
        case "getInitialNotification":
          let payload = self.pendingInitialNotification
          self.pendingInitialNotification = nil
          result(payload.map { AppDelegate.stringKeyed($0) })
        case "requestAuthorization":
          AppDelegate.requestAuthorization(application: UIApplication.shared) { result(nil) }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      self.pushChannel = channel
    }

    UNUserNotificationCenter.current().delegate = self

    // No authorization request here: it would prompt at cold start, before the
    // Config screen's Start initialises the SDK. Dart sends `requestAuthorization`
    // once the SDK is initialised, and APNs registration follows a grant from there.

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    NSLog("[Push] APNs device token: \(token)")
    pushChannel?.invokeMethod("apnsToken", arguments: token)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("[Push] APNs registration failed: \(error.localizedDescription)")
  }

  // Foreground delivery — show the alert so it is visible while testing.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  // Tap delivery (foreground/background, not cold-start) — forward userInfo to Dart.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    NSLog("[Push] notification tapped: \(userInfo)")
    pushChannel?.invokeMethod("notificationTapped", arguments: AppDelegate.stringKeyed(userInfo))
    completionHandler()
  }

  /// Shows the notification authorization prompt (it answers straight away once the
  /// user has decided) and, on a grant, registers for remote notifications — the token
  /// then reaches Dart through `apnsToken`, whose handler is set by now. Calls
  /// `completion` on the main queue either way.
  private static func requestAuthorization(
    application: UIApplication,
    completion: @escaping () -> Void
  ) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      if let error = error {
        NSLog("[Push] requestAuthorization error: \(error.localizedDescription)")
      }
      NSLog("[Push] authorization granted: \(granted)")
      DispatchQueue.main.async {
        if granted { application.registerForRemoteNotifications() }
        completion()
      }
    }
  }

  /// Convert `[AnyHashable: Any]` (APNs payload) to `[String: Any]` so Flutter's
  /// StandardMessageCodec can serialize it.
  private static func stringKeyed(_ dict: [AnyHashable: Any]) -> [String: Any] {
    var out: [String: Any] = [:]
    for (key, value) in dict {
      if let str = key as? String { out[str] = value }
    }
    return out
  }
}
