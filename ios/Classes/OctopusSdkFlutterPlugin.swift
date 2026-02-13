import Flutter
import UIKit
import SwiftUI
import Octopus
import OctopusUI
import Combine


public class OctopusSDKFlutterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var octopus: OctopusSDK?
  private var methodChannel: FlutterMethodChannel?
  private var eventChannel: FlutterEventChannel?
  private var eventSink: FlutterEventSink?
  private let eventEmitter = OctopusEventEmitter()
  private var cancellables = Set<AnyCancellable>()
  static var shared: OctopusSDKFlutterPlugin?
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
    let instance = OctopusSDKFlutterPlugin()
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
    case "initialize":
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
          case "PICTURE": return .picture
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
        OctopusSDKFlutterPlugin.shared?.octopus = octopus
        self.startObservingNotSeenNotificationsCount()
        self.startObservingHasAccessToCommunity()
        self.startObservingEvents()

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
        OctopusSDKFlutterPlugin.shared?.octopus = octopus
        self.startObservingNotSeenNotificationsCount()
        self.startObservingHasAccessToCommunity()
        self.startObservingEvents()

        result(nil)
      } catch {
        result(FlutterError(code: "INITIALIZATION_ERROR", message: error.localizedDescription, details: nil))
      }
    case "connectUser":
      guard let octopus else {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Call initialize() or initializeOctopusAuth() first", details: nil))
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
        result(FlutterError(code: "NOT_INITIALIZED", message: "Call initialize() or initializeOctopusAuth() first", details: nil))
        return
      }
      octopus.disconnectUser()
      result(nil)
    case "updateNotSeenNotificationsCount":
      guard let octopus else {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Call initialize() first", details: nil))
        return
      }
      Task {
        do {
          try await octopus.updateNotSeenNotificationsCount()
          result(nil)
        } catch {
          result(FlutterError(code: "UPDATE_ERROR", message: error.localizedDescription, details: nil))
        }
      }
    case "overrideCommunityAccess":
      guard let octopus else {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Call initialize() first", details: nil))
        return
      }
      guard let args = call.arguments as? [String: Any],
            let hasAccess = args["hasAccess"] as? Bool
      else {
        result(FlutterError(code: "INVALID_ARGS", message: "hasAccess is required", details: nil))
        return
      }
      Task {
        do {
          try await octopus.overrideCommunityAccess(hasAccess)
          result(nil)
        } catch {
          result(FlutterError(code: "OVERRIDE_ERROR", message: error.localizedDescription, details: nil))
        }
      }
    case "trackCommunityAccess":
      guard let octopus else {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Call initialize() first", details: nil))
        return
      }
      guard let args = call.arguments as? [String: Any],
            let hasAccess = args["hasAccess"] as? Bool
      else {
        result(FlutterError(code: "INVALID_ARGS", message: "hasAccess is required", details: nil))
        return
      }
      octopus.track(hasAccessToCommunity: hasAccess)
      result(nil)
    case "overrideDefaultLocale":
      guard let octopus else {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Call initialize() first", details: nil))
        return
      }
      let args = call.arguments as? [String: Any]
      let languageCode = args?["languageCode"] as? String
      let locale: Locale?
      if let languageCode {
        let countryCode = args?["countryCode"] as? String
        if let countryCode {
          locale = Locale(identifier: "\(languageCode)_\(countryCode)")
        } else {
          locale = Locale(identifier: languageCode)
        }
      } else {
        locale = nil
      }
      octopus.overrideDefaultLocale(with: locale)
      result(nil)
    case "trackCustomEvent":
      guard let octopus else {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Call initialize() first", details: nil))
        return
      }
      guard let args = call.arguments as? [String: Any],
            let name = args["name"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGS", message: "name is required", details: nil))
        return
      }
      let properties = (args["properties"] as? [String: String]) ?? [:]
      let customEvent = CustomEvent(
        name: name,
        properties: properties.mapValues { CustomEvent.PropertyValue(value: $0) }
      )
      Task {
        do {
          try await octopus.track(customEvent: customEvent)
          result(nil)
        } catch {
          result(FlutterError(code: "TRACK_ERROR", message: error.localizedDescription, details: nil))
        }
      }
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

  // MARK: - Observation helpers

  private func startObservingNotSeenNotificationsCount() {
    guard let octopus else { return }
    octopus.$notSeenNotificationsCount
      .receive(on: DispatchQueue.main)
      .sink { [weak self] count in
        self?.sendEvent("notSeenNotificationsCountChanged", data: ["count": count])
      }
      .store(in: &cancellables)
  }

  private func startObservingHasAccessToCommunity() {
    guard let octopus else { return }
    octopus.$hasAccessToCommunity
      .receive(on: DispatchQueue.main)
      .sink { [weak self] hasAccess in
        self?.sendEvent("hasAccessToCommunityChanged", data: ["hasAccess": hasAccess])
      }
      .store(in: &cancellables)
  }

  private func startObservingEvents() {
    guard let octopus else { return }
    octopus.eventPublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] event in
        if let data = self?.serializeEvent(event) {
          self?.sendEvent("sdkEvent", data: data)
        }
      }
      .store(in: &cancellables)
  }

  private func serializeEvent(_ event: OctopusEvent) -> [String: Any]? {
    switch event {
    case .postCreated(let context):
      var contentList: [String] = []
      if context.content.contains(.text) { contentList.append("text") }
      if context.content.contains(.image) { contentList.append("image") }
      if context.content.contains(.poll) { contentList.append("poll") }
      return [
        "type": "postCreated",
        "postId": context.postId,
        "content": contentList,
        "topicId": context.topicId,
        "textLength": context.textLength
      ]
    case .commentCreated(let context):
      return [
        "type": "commentCreated",
        "commentId": context.commentId,
        "postId": context.postId,
        "textLength": context.textLength
      ]
    case .replyCreated(let context):
      return [
        "type": "replyCreated",
        "replyId": context.replyId,
        "commentId": context.commentId,
        "textLength": context.textLength
      ]
    case .contentDeleted(let context):
      return [
        "type": "contentDeleted",
        "contentId": context.contentId,
        "contentKind": serializeContentKind(context.kind)
      ]
    case .reactionModified(let context):
      var data: [String: Any] = [
        "type": "reactionModified",
        "contentId": context.contentId,
        "contentKind": serializeContentKind(context.contentKind)
      ]
      if let prev = context.previousReaction {
        data["previousReaction"] = serializeReactionKind(prev)
      }
      if let next = context.newReaction {
        data["newReaction"] = serializeReactionKind(next)
      }
      return data
    case .pollVoted(let context):
      return [
        "type": "pollVoted",
        "contentId": context.contentId,
        "optionId": context.optionId
      ]
    case .contentReported(let context):
      return [
        "type": "contentReported",
        "contentId": context.contentId,
        "reasons": context.reasons.map { serializeReportReason($0) }
      ]
    case .gamificationPointsGained(let context):
      return [
        "type": "gamificationPointsGained",
        "points": context.pointsGained,
        "action": serializeGamificationPointsGainedAction(context.action)
      ]
    case .gamificationPointsRemoved(let context):
      return [
        "type": "gamificationPointsRemoved",
        "points": context.pointsRemoved,
        "action": serializeGamificationPointsRemovedAction(context.action)
      ]
    case .screenDisplayed(let context):
      return [
        "type": "screenDisplayed",
        "screen": serializeScreen(context.screen)
      ]
    case .notificationClicked(let context):
      var data: [String: Any] = [
        "type": "notificationClicked",
        "notificationId": context.notificationId
      ]
      if let contentId = context.contentId {
        data["contentId"] = contentId
      }
      return data
    case .postClicked(let context):
      return [
        "type": "postClicked",
        "postId": context.postId,
        "source": serializePostClickedSource(context.source)
      ]
    case .translationButtonClicked(let context):
      return [
        "type": "translationButtonClicked",
        "contentId": context.contentId,
        "viewTranslated": context.viewTranslated,
        "contentKind": serializeContentKind(context.contentKind)
      ]
    case .commentButtonClicked(let context):
      return [
        "type": "commentButtonClicked",
        "postId": context.postId
      ]
    case .replyButtonClicked(let context):
      return [
        "type": "replyButtonClicked",
        "commentId": context.commentId
      ]
    case .seeRepliesButtonClicked(let context):
      return [
        "type": "seeRepliesButtonClicked",
        "commentId": context.commentId
      ]
    case .profileModified(let context):
      var data: [String: Any] = [
        "type": "profileModified",
        "nicknameUpdated": context.nickname.isUpdated,
        "bioUpdated": context.bio.isUpdated,
        "pictureUpdated": context.picture.isUpdated
      ]
      if case .updated(let bioContext) = context.bio {
        data["bioLength"] = bioContext.bioLength
      }
      if case .updated(let pictureContext) = context.picture {
        data["hasPicture"] = pictureContext.hasPicture
      }
      return data
    case .sessionStarted(let context):
      return [
        "type": "sessionStarted",
        "sessionId": context.sessionId
      ]
    case .sessionStopped(let context):
      return [
        "type": "sessionStopped",
        "sessionId": context.sessionId
      ]
    @unknown default:
      return nil
    }
  }

  private func serializeContentKind(_ kind: OctopusEvent.ContentKind) -> String {
    switch kind {
    case .post: return "post"
    case .comment: return "comment"
    case .reply: return "reply"
    }
  }

  private func serializeReactionKind(_ kind: OctopusEvent.ReactionKind) -> String {
    switch kind {
    case .heart: return "heart"
    case .joy: return "joy"
    case .mouthOpen: return "mouthOpen"
    case .clap: return "clap"
    case .cry: return "cry"
    case .rage: return "rage"
    case .unknown: return "unknown"
    }
  }

  private func serializeReportReason(_ reason: OctopusEvent.ReportReason) -> String {
    switch reason {
    case .hateSpeechOrDiscriminationOrHarassment: return "hateSpeech"
    case .explicitOrInappropriateContent: return "explicit"
    case .violenceAndTerrorism: return "violence"
    case .spamAndScams: return "spam"
    case .suicideAndSelfHarm: return "suicide"
    case .fakeProfilesAndImpersonation: return "fakeProfile"
    case .childExploitationOrAbuse: return "childExploitation"
    case .intellectualPropertyViolation: return "intellectualProperty"
    case .other: return "other"
    }
  }

  private func serializeGamificationPointsGainedAction(_ action: OctopusEvent.GamificationPointsGainedAction) -> String {
    switch action {
    case .post: return "post"
    case .comment: return "comment"
    case .reply: return "reply"
    case .reaction: return "reaction"
    case .vote: return "vote"
    case .postCommented: return "postCommented"
    case .profileCompleted: return "profileCompleted"
    case .dailySession: return "dailySession"
    }
  }

  private func serializeGamificationPointsRemovedAction(_ action: OctopusEvent.GamificationPointsRemovedAction) -> String {
    switch action {
    case .postDeleted: return "postDeleted"
    case .commentDeleted: return "commentDeleted"
    case .replyDeleted: return "replyDeleted"
    case .reactionDeleted: return "reactionDeleted"
    }
  }

  private func serializePostClickedSource(_ source: OctopusEvent.PostClickedSource) -> String {
    switch source {
    case .feed: return "feed"
    case .profile: return "profile"
    }
  }

  private func serializeScreen(_ screen: OctopusEvent.Screen) -> [String: Any] {
    switch screen {
    case .postsFeed(let context):
      var data: [String: Any] = ["type": "postsFeed", "feedId": context.feedId]
      if let relatedTopicId = context.relatedTopicId {
        data["relatedTopicId"] = relatedTopicId
      }
      return data
    case .postDetail(let context):
      return ["type": "postDetail", "postId": context.postId]
    case .commentDetail(let context):
      return ["type": "commentDetail", "commentId": context.commentId]
    case .createPost:
      return ["type": "createPost"]
    case .profile:
      return ["type": "profile"]
    case .otherUserProfile(let context):
      return ["type": "otherUserProfile", "profileId": context.profileId]
    case .editProfile:
      return ["type": "editProfile"]
    case .reportContent:
      return ["type": "reportContent"]
    case .reportProfile:
      return ["type": "reportProfile"]
    case .validateNickname:
      return ["type": "validateNickname"]
    case .settingsList:
      return ["type": "settingsList"]
    case .settingsAccount:
      return ["type": "settingsAccount"]
    case .settingsAbout:
      return ["type": "settingsAbout"]
    case .reportExplanation:
      return ["type": "reportExplanation"]
    case .deleteAccount:
      return ["type": "deleteAccount"]
    }
  }

  private func sendEvent(_ eventName: String, data: [String: Any]? = nil) {
    var eventData: [String: Any] = ["event": eventName]
    if let data { eventData.merge(data) { _, new in new } }
    eventSink?(eventData)
  }

  private func profileFieldToString(_ profileField: ConnectionMode.SSOConfiguration.ProfileField?) -> String? {
    switch profileField {
    case .nickname:
      return "NICKNAME"
    case .bio:
      return "BIO"
    case .picture:
      return "PICTURE"
    default:
      return nil
    }
  }
}
