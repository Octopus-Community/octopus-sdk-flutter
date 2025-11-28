import Flutter
import UIKit
import SwiftUI
import Octopus
import OctopusUI
import Combine


public class OctopusSdkFlutterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var octopus: OctopusSDK?
  private var methodChannel: FlutterMethodChannel?
  private var eventChannel: FlutterEventChannel?
  private var eventSink: FlutterEventSink?
  private let eventEmitter = OctopusEventEmitter()
  static var shared: OctopusSdkFlutterPlugin?
  static var sharedOctopus: OctopusSDK? { shared?.octopus }
  
  
  static func triggerCallback(method: String, callbackId: String) {
    print("iOS Plugin: triggerCallback called: method=\(method), callbackId=\(callbackId)")
    shared?.methodChannel?.invokeMethod(method, arguments: callbackId)
    print("iOS Plugin: triggerCallback completed")
  }
  
  static func triggerCallbackWithArgs(method: String, args: [String: Any]) {
    print("iOS Plugin: triggerCallbackWithArgs called: method=\(method), args=\(args)")
    shared?.methodChannel?.invokeMethod(method, arguments: args)
    print("iOS Plugin: triggerCallbackWithArgs completed")
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "octopus_sdk_flutter", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(name: "octopus_sdk_flutter/events", binaryMessenger: registrar.messenger())
    let instance = OctopusSdkFlutterPlugin()
    instance.methodChannel = channel
    instance.eventChannel = eventChannel
    registrar.addMethodCallDelegate(instance, channel: channel)
    eventChannel.setStreamHandler(instance)
    shared = instance

    // Set up event emitter
    instance.eventEmitter.setMethodChannel(channel)
    OctopusEventEmitter.shared = instance.eventEmitter

    // Register embedded platform view factory
    registrar.register(OctopusViewFactory(messenger: registrar.messenger()), withId: "octopus_sdk_flutter/native_view")
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "initializeOctopusSDK":
      guard let args = call.arguments as? [String: Any],
            let apiKey = args["apiKey"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGS", message: "apiKey is required", details: nil))
        return
      }

      let appManagedFields = args["appManagedFields"] as? [String] ?? []
      
      do {
        // Always reset previous instance to avoid stale state
        if let existing = octopus {
          existing.disconnectUser()
        }
        
        // Convert string fields to ProfileField enum
        let profileFields: Set<ConnectionMode.SSOConfiguration.ProfileField> = Set(appManagedFields.compactMap { fieldName in
          switch fieldName {
          case "NICKNAME": return .nickname
          case "AVATAR": return .picture
          case "BIO": return .bio
          default: return nil
          }
        })
        
        // Initialize SDK according to documentation
        if !profileFields.isEmpty {
          // With app managed fields
          octopus = try OctopusSDK(
            apiKey: apiKey,
            connectionMode: .sso(.init(
              appManagedFields: profileFields,
              loginRequired: {
                print("iOS: SDK loginRequired callback triggered")
                self.eventEmitter.emitLoginRequired()
              },
              modifyUser: { fieldToEdit in
                print("iOS: SDK modifyUser callback triggered: \(fieldToEdit)")
                let fieldString = self.profileFieldToString(fieldToEdit)
                self.eventEmitter.emitEditUser(fieldToEdit: fieldString)
              }
            ))
          )
        } else {
          // Without app managed fields
          octopus = try OctopusSDK(
            apiKey: apiKey,
            connectionMode: .sso(.init(
              loginRequired: {
                print("iOS: SDK loginRequired callback triggered")
                self.eventEmitter.emitLoginRequired()
              }
            ))
          )
        }
        
        guard let octopus else { throw NSError(domain: "octopus", code: -20) }
        OctopusSdkFlutterPlugin.shared?.octopus = octopus
        
        result(nil)
      } catch {
        result(FlutterError(code: "INITIALIZATION_ERROR", message: error.localizedDescription, details: nil))
      }
    case "initializeOctopusAuth":
      guard let args = call.arguments as? [String: Any],
            let apiKey = args["apiKey"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGS", message: "apiKey is required", details: nil))
        return
      }

      let deepLink = args["deepLink"] as? String
      
      do {
        // Always reset previous instance to avoid stale state
        if let existing = octopus {
          existing.disconnectUser()
        }
        
        // Initialize SDK with Octopus Auth mode
        octopus = try OctopusSDK(
          apiKey: apiKey,
          connectionMode: .octopus(deepLink: deepLink)
        )
        
        guard let octopus else { throw NSError(domain: "octopus", code: -20) }
        OctopusSdkFlutterPlugin.shared?.octopus = octopus
        
        result(nil)
      } catch {
        result(FlutterError(code: "INITIALIZATION_ERROR", message: error.localizedDescription, details: nil))
      }
    case "connectUser":
      guard let octopus else {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Call initializeOctopusSDK or initializeOctopusAuth first", details: nil))
        return
      }
      
      guard let args = call.arguments as? [String: Any],
            let userId = args["userId"] as? String,
            let token = args["token"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGS", message: "userId and token are required", details: nil))
        return
      }

      let nickname = args["nickname"] as? String
      let bio = args["bio"] as? String
      let picture = args["picture"] as? String


      // Convert picture string (URL or base64) to Data
      let pictureData: Data? = {
        guard let picture = picture else { return nil }
        
        // If it's a base64 string, decode it
        if picture.hasPrefix("data:") {
          if let commaIndex = picture.firstIndex(of: ",") {
            let base64String = String(picture[picture.index(after: commaIndex)...])
            return Data(base64Encoded: base64String)
          }
          return nil
        } else if !picture.hasPrefix("http") {
          // Assume it's base64 without data: prefix
          return Data(base64Encoded: picture)
        } else {
          // It's a URL, but we can't download it synchronously here
          // The SDK should handle URL pictures, so we'll skip this for now
          return nil
        }
      }()

      let profile = ClientUser.Profile(
        nickname: nickname,
        bio: bio,
        picture: pictureData
      )

      let clientUser = ClientUser(userId: userId, profile: profile)

      octopus.connectUser(clientUser) { @Sendable in
        return token
      }

      result(nil)
    case "disconnectUser":
      guard let octopus else {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Call initializeOctopusSDK or initializeOctopusAuth first", details: nil))
        return
      }
      octopus.disconnectUser()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func uiColorFromHex(_ hex: String) -> UIColor? {
    var c = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    if c.hasPrefix("#") { c.removeFirst() }
    guard c.count == 6 else { return nil }
    var rgb: UInt64 = 0
    Scanner(string: c).scanHexInt64(&rgb)
    return UIColor(
      red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
      green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
      blue: CGFloat(rgb & 0x0000FF) / 255.0,
      alpha: 1.0
    )
  }

  static func uiColorFromARGBInt(_ argb: Int) -> UIColor {
    let a = CGFloat((argb >> 24) & 0xFF) / 255.0
    let r = CGFloat((argb >> 16) & 0xFF) / 255.0
    let g = CGFloat((argb >> 8) & 0xFF) / 255.0
    let b = CGFloat(argb & 0xFF) / 255.0
    return UIColor(red: r, green: g, blue: b, alpha: a)
  }

  static func swiftUIColor(from uiColor: UIColor) -> Color {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 1
    uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return Color(red: Double(red), green: Double(green), blue: Double(blue), opacity: Double(alpha))
  }

  static func buildTheme(main: UIColor, low: UIColor, high: UIColor, onPrimary: UIColor, logoBase64: String?, 
                        fontSizeTitle1: Int = 26, fontSizeTitle2: Int = 20, fontSizeBody1: Int = 17, 
                        fontSizeBody2: Int = 14, fontSizeCaption1: Int = 12, fontSizeCaption2: Int = 10,
                        themeMode: String? = nil) -> OctopusTheme {
    print("iOS: buildTheme called with themeMode: \(themeMode ?? "nil")")
    
    // Adjust colors based on theme mode
    let adjustedMain: UIColor
    let adjustedLow: UIColor
    let adjustedHigh: UIColor
    let adjustedOnPrimary: UIColor
    
    switch themeMode {
    case "dark":
      // For dark mode, use colors suitable for dark backgrounds
      adjustedMain = main
      adjustedLow = low
      adjustedHigh = high
      adjustedOnPrimary = onPrimary
    case "light":
      // For light mode, use colors suitable for light backgrounds
      adjustedMain = main
      adjustedLow = low
      adjustedHigh = high
      adjustedOnPrimary = onPrimary
    default:
      // Use system appearance or default colors
      adjustedMain = main
      adjustedLow = low
      adjustedHigh = high
      adjustedOnPrimary = onPrimary
    }
    
    var theme = OctopusTheme(
      colors: .init(
        primarySet: .init(
          main: swiftUIColor(from: adjustedMain),
          lowContrast: swiftUIColor(from: adjustedLow),
          highContrast: swiftUIColor(from: adjustedHigh)
        ),
        onPrimary: swiftUIColor(from: adjustedOnPrimary)
      ),
      fonts: .init(
        title1: .system(size: CGFloat(fontSizeTitle1)),
        title2: .system(size: CGFloat(fontSizeTitle2)),
        body1: .system(size: CGFloat(fontSizeBody1)),
        body2: .system(size: CGFloat(fontSizeBody2)),
        caption1: .system(size: CGFloat(fontSizeCaption1)),
        caption2: .system(size: CGFloat(fontSizeCaption2)),
        navBarItem: .system(size: CGFloat(fontSizeBody1)) // Using body1 size for nav bar items
      )
    )
    if let logoBase64, let data = Data(base64Encoded: logoBase64), let image = UIImage(data: data) {
      theme = OctopusTheme(colors: theme.colors, fonts: theme.fonts, assets: .init(logo: image))
    }
    return theme
  }

  private static func topMostViewController(base: UIViewController? = {
    if #available(iOS 15.0, *) {
      return UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }?
        .rootViewController
    } else {
      return UIApplication.shared.windows.first { $0.isKeyWindow }?.rootViewController
    }
  }()) -> UIViewController? {
    if let nav = base as? UINavigationController { return topMostViewController(base: nav.visibleViewController) }
    if let tab = base as? UITabBarController { return topMostViewController(base: tab.selectedViewController) }
    if let presented = base?.presentedViewController { return topMostViewController(base: presented) }
    return base
  }

  // MARK: - FlutterStreamHandler implementation
  
  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    eventEmitter.setEventSink(events)
    return nil
  }
  
  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    eventEmitter.setEventSink(nil)
    return nil
  }

  // No token fetching in the plugin. Token must be provided by Flutter.
  
  private func profileFieldToString(_ profileField: ConnectionMode.SSOConfiguration.ProfileField?) -> String? {
    switch profileField {
    case .nickname:
      return "NICKNAME"
    case .bio:
      return "BIO"
    case .picture:
      return "AVATAR"
    default:
      return nil
    }
  }
}
