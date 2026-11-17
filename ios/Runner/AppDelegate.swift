import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Set before launch finishes, as iOS requires. Flutter passes the
    // callbacks on to the plugins, so Firebase Messaging still reports
    // pushes and taps; this class only decides how a push shows while the
    // app is open.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// A push arriving while the app is open. Firebase reports it to the Dart
  /// side as usual; then the system's own banner shows it, as it does while
  /// the app is closed, unless it is for the chat on screen. The system draws
  /// it in the phone's light or dark appearance, not the app's, and plays the
  /// notification sound if the user has it on. It stays out of Notification
  /// Center and leaves the badge to the app, which keeps it current while
  /// open.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Firebase's own options (none) are replaced by the ones below.
    super.userNotificationCenter(center, willPresent: notification) { _ in }

    let userInfo = notification.request.content.userInfo
    guard userInfo["gcm.message_id"] != nil else {
      completionHandler([])
      return
    }
    NotificationTrayChannel.shouldShowBanner(userInfo) { show in
      completionHandler(show ? [.banner, .sound] : [])
    }
  }

  /// With the UIScene lifecycle the engine is created by the scene's
  /// FlutterViewController, so plugins and channels register here.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BleyaAppBadge") {
      AppBadgeChannel.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BleyaNotificationTray") {
      NotificationTrayChannel.register(with: registrar.messenger())
    }
  }
}

/// The app's notifications on the lock screen and in Notification Center,
/// for the Dart side (`NotificationTrayService`): `clearAll` on the
/// `bleya/notifications` channel removes them, `clearChat` only one chat's.
/// The badge stays as it is.
/// Before a push shows while the app is open, `shouldShowBanner` asks the
/// Dart side whether it is for the chat on screen.
enum NotificationTrayChannel {
  private static var channel: FlutterMethodChannel?

  /// How long a push waits for the Dart side's answer before it shows.
  private static let answerTimeout: TimeInterval = 1

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "bleya/notifications", binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "clearAll":
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        result(nil)
      case "clearChat":
        let arguments = call.arguments as? [String: Any]
        clearChat(
          roomId: arguments?["roomId"] as? String,
          threadId: arguments?["threadId"] as? String,
          result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Removes the notifications of one chat: a room's new messages, or a
  /// thread's replies. Each push's data (`type`, `roomId`, `threadId`) is in
  /// its userInfo. Other chats' notifications stay.
  private static func clearChat(roomId: String?, threadId: String?, result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()
    center.getDeliveredNotifications { notifications in
      let identifiers = notifications.filter { notification in
        let data = notification.request.content.userInfo
        switch data["type"] as? String {
        case "message":
          return roomId != nil && data["roomId"] as? String == roomId
        case "reply":
          return threadId != nil && data["threadId"] as? String == threadId
        default:
          return false
        }
      }.map { $0.request.identifier }
      if !identifiers.isEmpty {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
      }
      DispatchQueue.main.async { result(nil) }
    }
  }

  /// Whether the push with [userInfo] shows as a banner. It shows when the
  /// Dart side doesn't answer in time, isn't running or has no answer.
  static func shouldShowBanner(
    _ userInfo: [AnyHashable: Any],
    completion: @escaping (Bool) -> Void
  ) {
    guard let channel = channel else {
      completion(true)
      return
    }
    var answered = false
    let answer: (Bool) -> Void = { show in
      guard !answered else { return }
      answered = true
      completion(show)
    }
    // Only the push's own data: Firebase's keys and `aps` aren't needed.
    var data: [String: Any] = [:]
    for (key, value) in userInfo {
      if let key = key as? String, let value = value as? String {
        data[key] = value
      }
    }
    channel.invokeMethod("shouldShowBanner", arguments: data) { result in
      DispatchQueue.main.async { answer((result as? Bool) ?? true) }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + answerTimeout) { answer(true) }
  }
}

/// The app-icon badge for the Dart side (`AppBadgeService`):
/// `setBadgeCount(n)` on the `bleya/badge` channel, where 0 removes it.
enum AppBadgeChannel {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "bleya/badge", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "setBadgeCount" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let count = call.arguments as? Int, count >= 0 else {
        result(FlutterError(
          code: "invalid-count",
          message: "The badge count must be a whole number of 0 or more.",
          details: nil))
        return
      }
      setBadgeCount(count, result: result)
    }
  }

  private static func setBadgeCount(_ count: Int, result: @escaping FlutterResult) {
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(count) { error in
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(
              code: "badge-failed",
              message: error.localizedDescription,
              details: nil))
          } else {
            result(nil)
          }
        }
      }
    } else {
      UIApplication.shared.applicationIconBadgeNumber = count
      result(nil)
    }
  }
}
