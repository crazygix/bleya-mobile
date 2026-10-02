import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "BleyaAppBadge") {
      AppBadgeChannel.register(with: registrar.messenger())
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
