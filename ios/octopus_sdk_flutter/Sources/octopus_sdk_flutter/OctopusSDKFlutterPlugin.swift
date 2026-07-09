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
  /// Parked bridge token requests, keyed by the in-flight requestId. The
  /// `fetchOrCreateClientObjectRelatedPost` tokenProvider block stores its
  /// continuation here and awaits it; the Dart `provideBridgeToken` reply
  /// resumes it. Accessed only on the main thread.
  private var bridgeTokenContinuations: [String: CheckedContinuation<String?, Never>] = [:]
  /// Parked client-user-token requests, keyed by the in-flight requestId.
  /// `connectUserWithTokenProvider`'s closure registers a continuation here
  /// and awaits it; the Dart `provideClientUserToken` reply resumes it.
  /// Accessed only on the main thread. The native SDK calls the closure
  /// initially (on connect) and again on every refresh (e.g. when
  /// `refreshEntitlements()` mints a new JWT) — each invocation gets a
  /// fresh requestId so concurrent refreshes can't race.
  private var clientUserTokenContinuations: [String: CheckedContinuation<String, Never>] = [:]
  private var clientUserTokenRequestCounter: Int = 0
  /// Active client-object-post observations, keyed by the Dart-supplied
  /// observationId (one per getClientObjectRelatedPostFlow subscription).
  private var clientObjectPostCancellables: [String: AnyCancellable] = [:]
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

  /// Builds an `OctopusSDK.Configuration` from the optional `apiServer`
  /// argument. Returns the default configuration when `apiServer` is absent.
  /// The `ApiServer` initializer validates the host and throws on malformed
  /// input (caught by the caller's do/catch).
  private static func parseConfiguration(_ args: [String: Any]) throws -> OctopusSDK.Configuration {
    guard let apiServerArgs = args["apiServer"] as? [String: Any],
          let host = apiServerArgs["host"] as? String
    else {
      return OctopusSDK.Configuration()
    }
    let port = (apiServerArgs["port"] as? NSNumber)?.intValue
      ?? (apiServerArgs["port"] as? Int)
      ?? 443
    let apiServer = try OctopusSDK.Configuration.ApiServer(host: host, port: port)
    return OctopusSDK.Configuration(apiServer: apiServer)
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
        let configuration = try Self.parseConfiguration(args)
        try setupSSO(apiKey: apiKey, appManagedFields: appManagedFields, configuration: configuration)
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
        let configuration = try Self.parseConfiguration(args)
        try setupOctopusAuth(apiKey: apiKey, deepLink: deepLink, configuration: configuration)
        result(nil)
      } catch {
        result(FlutterError(code: "INITIALIZATION_ERROR", message: error.localizedDescription, details: nil))
      }
    case "switchCommunity":
      guard let args = call.arguments as? [String: Any],
            let apiKey = args["apiKey"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGS", message: "apiKey is required", details: nil))
        return
      }

      let appManagedFields = args["appManagedFields"] as? [String] ?? []

      do {
        let configuration = try Self.parseConfiguration(args)
        performSwitchCommunity(
          apiKey: apiKey,
          connectionMode: makeSSOConnectionMode(appManagedFields),
          configuration: configuration,
          result: result
        )
      } catch {
        result(FlutterError(code: "SWITCH_COMMUNITY_ERROR", message: error.localizedDescription, details: nil))
      }
    case "switchCommunityOctopusAuth":
      guard let args = call.arguments as? [String: Any],
            let apiKey = args["apiKey"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGS", message: "apiKey is required", details: nil))
        return
      }

      let deepLink = args["deepLink"] as? String

      do {
        let configuration = try Self.parseConfiguration(args)
        performSwitchCommunity(
          apiKey: apiKey,
          connectionMode: .octopus(deepLink: deepLink),
          configuration: configuration,
          result: result
        )
      } catch {
        result(FlutterError(code: "SWITCH_COMMUNITY_ERROR", message: error.localizedDescription, details: nil))
      }
    case "reset":
      // iOS has no native reset(); disconnect the user (best-effort match for
      // Android, which also clears local cache). No-op if uninitialized. The
      // SDK stays initialized.
      octopus?.disconnectUser()
      result(nil)
    case "stop":
      // iOS has no native stop(); release the instance and tear down observers
      // so the SDK returns to an uninitialized state. No-op if already stopped.
      octopus?.disconnectUser()
      octopus = nil
      OctopusSDKFlutterPlugin.shared?.octopus = nil
      cancellables.removeAll()
      clientObjectPostCancellables.values.forEach { $0.cancel() }
      clientObjectPostCancellables.removeAll()
      emitIsInitialised()
      result(nil)
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
    case "connectUserWithTokenProvider":
      // Persistent tokenProvider path — mirrors Android's
      // `OctopusSDK.connectUser(user, tokenProvider: suspend () -> String)`.
      // The native SDK calls the closure initially AND on every refresh
      // (e.g. `refreshEntitlements()` minting a fresh JWT with the host's
      // current entitlement set), so the closure must round-trip back to
      // Dart on every invocation — not just capture a static token.
      guard let octopus else {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Call initialize() or initializeOctopusAuth() first", details: nil))
        return
      }
      guard let args = call.arguments as? [String: Any],
            let userId = args["userId"] as? String,
            let providerId = args["providerId"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGS", message: "userId and providerId are required", details: nil))
        return
      }
      let nickname = args["nickname"] as? String
      let bio = args["bio"] as? String
      let picture = args["picture"] as? String
      let pictureData: Data? = {
        guard let picture = picture else { return nil }
        if picture.hasPrefix("data:") {
          if let commaIndex = picture.firstIndex(of: ",") {
            let base64String = String(picture[picture.index(after: commaIndex)...])
            return Data(base64Encoded: base64String)
          }
          return nil
        } else if !picture.hasPrefix("http") {
          return Data(base64Encoded: picture)
        }
        return nil
      }()
      let profile = ClientUser.Profile(nickname: nickname, bio: bio, picture: pictureData)
      let clientUser = ClientUser(userId: userId, profile: profile)
      // Capture `self` weakly outside the @Sendable closure (Swift forbids
      // a capture list inside the @Sendable attribute). The plugin's
      // lifetime is the app's, so the weak ref is effectively non-nil here,
      // but we still null-check for hygiene.
      weak var weakSelf = self
      octopus.connectUser(clientUser) { @Sendable in
        // Each invocation gets a fresh requestId so concurrent refreshes
        // can't race (the SDK may invoke this closure multiple times across
        // the connection's lifetime — initial connect, every refresh).
        return await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
          DispatchQueue.main.async {
            guard let s = weakSelf else {
              continuation.resume(returning: "")
              return
            }
            s.clientUserTokenRequestCounter += 1
            let requestId = "clientUserToken_\(s.clientUserTokenRequestCounter)"
            s.clientUserTokenContinuations[requestId] = continuation
            s.sendEvent(
              "clientUserTokenRequest",
              data: ["providerId": providerId, "requestId": requestId]
            )
          }
        }
      }
      result(nil)
    case "provideClientUserToken":
      // Resume the parked closure with the freshly-signed JWT (or an empty
      // string if the Dart side couldn't sign — the native SDK treats an
      // empty token as a tokenProvider failure).
      guard let args = call.arguments as? [String: Any],
            let requestId = args["requestId"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGS", message: "requestId is required", details: nil))
        return
      }
      let token = args["token"] as? String ?? ""
      let parked = clientUserTokenContinuations.removeValue(forKey: requestId)
      parked?.resume(returning: token)
      result(nil)
    case "disconnectUser":
      guard let octopus else {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Call initialize() or initializeOctopusAuth() first", details: nil))
        return
      }
      // Drain any parked client-user-token continuations before disconnecting.
      // The native SDK drops its ref to the persistent tokenProvider closure
      // on disconnect WITHOUT invoking it, so a continuation parked in
      // `clientUserTokenContinuations` (a refresh in-flight when the host
      // calls disconnect) would otherwise leak and produce an
      // "un-resumed CheckedContinuation" Swift runtime warning. Resume each
      // with `""` (the empty-token convention) and clear the map.
      // Android's `try { await } finally { remove }` self-heals via the
      // SDK's own coroutine cancellation; iOS has no such hook.
      let parked = clientUserTokenContinuations
      clientUserTokenContinuations.removeAll()
      for (_, continuation) in parked {
        continuation.resume(returning: "")
      }
      octopus.disconnectUser()
      result(nil)
    case "showCreatePostScreen":
      OctopusCreatePostPresenter.present(args: call.arguments as? [String: Any], result: result)
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
          result(["type": "success"])
        } catch {
          // iOS throws an untyped error for this call (no OctopusResult / no
          // typed OverrideCommunityAccessError). Surface it as a typed
          // `unknown` error so the Dart OctopusResult is consistent with
          // Android. iOS does not distinguish connection vs business failures
          // here, so all handled failures map to invalidArguments(unknown).
          result([
            "type": "failure",
            "kind": "invalidArguments",
            "errors": [["type": "unknown", "message": error.localizedDescription]],
          ])
        }
      }
    case "refreshEntitlements":
      guard let octopus else {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Call initialize() first", details: nil))
        return
      }
      Task {
        do {
          try await octopus.refreshEntitlements()
          result(["type": "success"])
        } catch let e as OctopusRefreshEntitlementsError {
          // Map the typed iOS error into the shared OctopusResult wire format
          // (invalidArguments + typed RefreshEntitlementsError). Messages are
          // aligned with the Android defaults for cross-platform parity; the
          // userBanned message is backend-provided and displayable.
          let error: [String: Any]
          switch e {
          case .noClientTokenProvider:
            error = ["type": "noClientTokenProvider", "message": "No client token provider registered"]
          case .userNotConnected:
            error = ["type": "userNotConnected", "message": "No connected user"]
          case .noNetwork:
            error = ["type": "noNetwork", "message": "No network"]
          case .userBanned(let message):
            error = ["type": "userBanned", "message": message]
          case .serverError(let underlying):
            error = ["type": "serverError", "message": "\(underlying)"]
          }
          result(["type": "failure", "kind": "invalidArguments", "errors": [error]])
        } catch {
          result([
            "type": "failure",
            "kind": "invalidArguments",
            "errors": [["type": "serverError", "message": error.localizedDescription]],
          ])
        }
      }
    case "setReaction":
      guard let octopus else {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Call initialize() first", details: nil))
        return
      }
      guard let args = call.arguments as? [String: Any],
            let postId = args["postId"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGS", message: "postId is required", details: nil))
        return
      }
      let reaction = deserializeReactionKind(args["reaction"] as? [String: Any])
      Task {
        do {
          try await octopus.set(reaction: reaction, postId: postId)
          result(["type": "success"])
        } catch let e as OctopusSetReactionError {
          // Map the typed iOS error into the shared OctopusResult wire format.
          // Connection/auth failures stay orthogonal (connection-failure branch),
          // matching the Android contract; the three business errors flow through
          // invalidArguments as a typed SetReactionError.
          switch e {
          case .noNetwork:
            result(["type": "failure", "kind": "noNetwork"])
          case .notConnected:
            result(["type": "failure", "kind": "userNotAuthenticated",
                    "reason": "No user is connected"])
          case .unknownReaction:
            result(["type": "failure", "kind": "invalidArguments",
                    "errors": [["type": "unknownReaction", "message": "Unknown reaction not permitted"]]])
          case .postNotFound:
            result(["type": "failure", "kind": "invalidArguments",
                    "errors": [["type": "postNotFound", "message": "Post not found"]]])
          case .serverError(let underlying):
            result(["type": "failure", "kind": "invalidArguments",
                    "errors": [["type": "reactionError", "message": "\(underlying)"]]])
          case .other(let underlying):
            result(["type": "failure", "kind": "invalidArguments",
                    "errors": [["type": "reactionError",
                                "message": underlying.map { "\($0)" } ?? "Reaction error"]]])
          }
        } catch {
          result(["type": "failure", "kind": "invalidArguments",
                  "errors": [["type": "reactionError", "message": error.localizedDescription]]])
        }
      }
    case "fetchOrCreateClientObjectRelatedPost":
      guard let octopus else {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Call initialize() first", details: nil))
        return
      }
      guard let args = call.arguments as? [String: Any],
            let clientPostMap = args["clientPost"] as? [String: Any],
            let requestId = args["requestId"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGS", message: "clientPost and requestId are required", details: nil))
        return
      }
      let hasTokenProvider = args["hasTokenProvider"] as? Bool ?? false
      let clientPost: ClientPost
      do {
        clientPost = try Self.decodeClientPost(clientPostMap)
      } catch {
        result(FlutterError(code: "INVALID_ARGS", message: error.localizedDescription, details: nil))
        return
      }
      // iOS requires a tokenProvider block. When the Dart caller did not supply
      // one, pass a block that always returns nil (no signature) — matching
      // Android's optional tokenProvider semantics. When supplied, reuse the
      // shared native→Dart round-trip (`requestBridgeToken`) also used by the
      // create-post editor's bridge-share signer.
      let tokenProvider: @Sendable (String) async throws -> String?
      if hasTokenProvider {
        tokenProvider = { [weak self] fingerprint in
          guard let self else { return nil }
          return await self.requestBridgeToken(requestId: requestId, fingerprint: fingerprint)
        }
      } else {
        tokenProvider = { _ in nil }
      }
      Task {
        do {
          let post = try await octopus.fetchOrCreateClientObjectRelatedPost(
            content: clientPost, tokenProvider: tokenProvider)
          result(["type": "success", "post": Self.serializeOctopusPost(post)])
        } catch let e as ClientPostError {
          result(Self.encodeClientPostError(e))
        } catch {
          result([
            "type": "failure", "kind": "invalidArguments",
            "errors": [["type": "other", "message": error.localizedDescription]],
          ])
        }
      }
    case "provideBridgeToken":
      guard let args = call.arguments as? [String: Any],
            let requestId = args["requestId"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGS", message: "requestId is required", details: nil))
        return
      }
      let token = args["token"] as? String
      // Resume the parked request. No-op if it already settled / unknown id.
      if let continuation = bridgeTokenContinuations.removeValue(forKey: requestId) {
        continuation.resume(returning: token)
      }
      result(nil)
    case "startClientObjectPostObservation":
      guard let octopus else {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Call initialize() first", details: nil))
        return
      }
      guard let args = call.arguments as? [String: Any],
            let observationId = args["observationId"] as? String,
            let clientObjectId = args["clientObjectId"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGS", message: "observationId and clientObjectId are required", details: nil))
        return
      }
      clientObjectPostCancellables[observationId]?.cancel()
      clientObjectPostCancellables[observationId] = octopus
        .getClientObjectRelatedPostPublisher(clientObjectId: clientObjectId)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] post in
          self?.sendEvent(
            "clientObjectPostChanged",
            data: [
              "observationId": observationId,
              "post": post.map { Self.serializeOctopusPost($0) } as Any,
            ]
          )
        }
      result(nil)
    case "stopClientObjectPostObservation":
      guard let args = call.arguments as? [String: Any],
            let observationId = args["observationId"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGS", message: "observationId is required", details: nil))
        return
      }
      clientObjectPostCancellables.removeValue(forKey: observationId)?.cancel()
      result(nil)
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
    case "registerPushNotificationToken":
      guard let octopus else {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Call initialize() first", details: nil))
        return
      }
      guard let args = call.arguments as? [String: Any],
            let token = args["token"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGS", message: "token is required", details: nil))
        return
      }
      octopus.set(notificationDeviceToken: token)
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
    case "fetchGroups":
      guard let octopus else {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Call initialize() first", details: nil))
        return
      }
      Task {
        do {
          try await octopus.fetchGroups()
          // The native call only refreshes the cache; the up-to-date list is
          // read from the published `groups` property after the await.
          let payload: [[String: Any]] = octopus.groups.map { Self.serializeOctopusGroup($0) }
          result(["type": "success", "groups": payload])
        } catch {
          // iOS throws an untyped Swift error; classify by ServerCallError into
          // the shared OctopusResult connection-failure kinds. fetchGroups
          // never carries a typed business error (Android `<_, Nothing>`).
          result(Self.encodeUntypedConnectionFailure(error))
        }
      }
    case "followGroup":
      guard let octopus else {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Call initialize() first", details: nil))
        return
      }
      guard let args = call.arguments as? [String: Any],
            let groupId = args["groupId"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGS", message: "groupId is required", details: nil))
        return
      }
      Task {
        result(await Self.syncSingleFollowAction(octopus: octopus, groupId: groupId, followed: true))
      }
    case "unfollowGroup":
      guard let octopus else {
        result(FlutterError(code: "NOT_INITIALIZED", message: "Call initialize() first", details: nil))
        return
      }
      guard let args = call.arguments as? [String: Any],
            let groupId = args["groupId"] as? String
      else {
        result(FlutterError(code: "INVALID_ARGS", message: "groupId is required", details: nil))
        return
      }
      Task {
        result(await Self.syncSingleFollowAction(octopus: octopus, groupId: groupId, followed: false))
      }
    case "syncFollowGroups":
      guard let octopus else {
        result(FlutterError(code: "not_connected", message: "Call initialize() and connectUser() first", details: nil))
        return
      }
      guard let args = call.arguments as? [String: Any],
            let rawActions = args["actions"] as? [[String: Any]]
      else {
        result(FlutterError(code: "other", message: "actions list is required", details: nil))
        return
      }
      if rawActions.isEmpty {
        result([] as [[String: Any]])
        return
      }
      let actions: [OctopusSyncFollowGroup.Action] = rawActions.compactMap { m in
        guard let groupId = m["groupId"] as? String,
              let followed = m["followed"] as? Bool,
              let ms = m["actionDateMs"] as? NSNumber
        else {
          NSLog("[OctopusSDK] syncFollowGroups: dropping malformed action entry \(m). Expected keys: groupId (String), followed (Bool), actionDateMs (Number).")
          return nil
        }
        let date = Date(timeIntervalSince1970: ms.doubleValue / 1000.0)
        return OctopusSyncFollowGroup.Action(
          groupId: groupId,
          followed: followed,
          actionDate: date
        )
      }
      Task {
        do {
          let nativeResults = try await octopus.syncFollowGroups(actions: actions)
          let payload: [[String: Any]] = nativeResults.map { r in
            ["groupId": r.groupId, "status": r.status.toWireValue()]
          }
          result(payload)
        } catch let error as OctopusSyncFollowGroup.Error {
          let code: String
          switch error {
          case .notConnected: code = "not_connected"
          case .noNetwork:    code = "no_network"
          case .server:       code = "server"
          case .other:        code = "other"
          }
          result(FlutterError(code: code, message: String(describing: error), details: nil))
        } catch {
          result(FlutterError(code: "other", message: error.localizedDescription, details: nil))
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Serializes a single [OctopusGroup] using the lean 6-field shape shared
  /// with the `groupsChanged` event (the iOS-intersection public surface).
  private static func serializeOctopusGroup(_ group: OctopusGroup) -> [String: Any] {
    return [
      "id": group.id,
      "name": group.name,
      "isFollowed": group.isFollowed,
      "canChangeFollowStatus": group.canChangeFollowStatus,
      "canAccess": group.canAccess,
      "canCreateChildren": group.canCreateChildren,
    ]
  }

  /// Encodes a Swift untyped `Error` from `octopus.fetchGroups()` into the
  /// shared `OctopusResult` failure wire shape. iOS has no typed business
  /// failure for fetchGroups (Android `<_, Nothing>`), so all errors degrade
  /// onto a connection-failure kind: `noNetwork` for the recognized network
  /// error, `userNotAuthenticated` when the underlying call complained about
  /// authentication, `statusError` otherwise. Mirrors how
  /// [OctopusResult.failureFromWire] decodes the wire on Dart.
  ///
  /// The native `Octopus` pod does not publicly expose the underlying error
  /// type (`OctopusCore.ServerCallError` lives in a separate module that the
  /// bridge does not import), so the classification relies on the error's
  /// string description. The recognized substrings match the cases of
  /// `OctopusCore.ServerCallError` / `ServerError` as of pod 1.12.0 — revisit
  /// this when the iOS SDK changes its enum names.
  private static func encodeUntypedConnectionFailure(_ error: Error) -> [String: Any] {
    let message = "\(error)"
    if message.range(of: "noNetwork", options: .caseInsensitive) != nil {
      return ["type": "failure", "kind": "noNetwork"]
    }
    if message.range(of: "notAuthenticated", options: .caseInsensitive) != nil
      || message.range(of: "notConnected", options: .caseInsensitive) != nil
    {
      return [
        "type": "failure",
        "kind": "userNotAuthenticated",
        "reason": error.localizedDescription,
      ]
    }
    return [
      "type": "failure",
      "kind": "statusError",
      "code": -1,
      "description": error.localizedDescription,
    ]
  }

  /// Runs a single-action `syncFollowGroups([Action])` and translates the
  /// outcome into the shared `OctopusResult` wire shape. iOS does not expose
  /// individual `followGroup` / `unfollowGroup` natively, so the bridge maps
  /// onto the batch API and inspects the per-action `Status` to produce a
  /// typed [GroupFollowUnfollowError]. RPC-level errors become connection
  /// failures.
  ///
  /// Idempotent-by-server statuses (`.applied`, `.skipped`) translate to
  /// [OctopusSuccess]. iOS exposes `.alreadyFollowed` / `.alreadyUnfollowed` /
  /// `.notFollowable` / `.notUnfollowable` separately, which we map onto the
  /// Android-aligned typed errors. iOS has no equivalent of
  /// `LastFollowedGroup` — unfollowing the last followed group succeeds
  /// silently on iOS.
  private static func syncSingleFollowAction(
    octopus: OctopusSDK,
    groupId: String,
    followed: Bool
  ) async -> [String: Any] {
    let action = OctopusSyncFollowGroup.Action(
      groupId: groupId,
      followed: followed,
      actionDate: Date()
    )
    do {
      let results = try await octopus.syncFollowGroups(actions: [action])
      guard let first = results.first else {
        // Defensive: the batch API guarantees one result per action, but if
        // the backend ever returns empty, surface it as an unknown business
        // error instead of falsely reporting success.
        return [
          "type": "failure",
          "kind": "invalidArguments",
          "errors": [["type": "unknown", "message": "Empty syncFollowGroups response"]],
        ]
      }
      switch first.status {
      case .applied, .skipped:
        return ["type": "success"]
      case .groupNotFound:
        return [
          "type": "failure",
          "kind": "invalidArguments",
          "errors": [["type": "missingGroup", "message": "Group not found"]],
        ]
      case .notFollowable, .notUnfollowable:
        return [
          "type": "failure",
          "kind": "invalidArguments",
          "errors": [["type": "unfollowableGroup", "message": "Group follow state cannot be changed"]],
        ]
      case .alreadyFollowed:
        return [
          "type": "failure",
          "kind": "invalidArguments",
          "errors": [["type": "groupAlreadyFollowed", "message": "Group is already followed"]],
        ]
      case .alreadyUnfollowed:
        return [
          "type": "failure",
          "kind": "invalidArguments",
          "errors": [["type": "groupAlreadyUnfollowed", "message": "Group is already not followed"]],
        ]
      case .unknownError:
        return [
          "type": "failure",
          "kind": "invalidArguments",
          "errors": [["type": "unknown", "message": "Unknown server error"]],
        ]
      @unknown default:
        return [
          "type": "failure",
          "kind": "invalidArguments",
          "errors": [["type": "unknown", "message": "Unhandled status"]],
        ]
      }
    } catch let e as OctopusSyncFollowGroup.Error {
      // RPC-level errors translate to the orthogonal connection-failure branch
      // so consumers handle them the same way as for any other SDK call.
      switch e {
      case .noNetwork:
        return ["type": "failure", "kind": "noNetwork"]
      case .notConnected:
        return [
          "type": "failure",
          "kind": "userNotAuthenticated",
          "reason": "No user is connected",
        ]
      case .server(let underlying):
        return [
          "type": "failure",
          "kind": "statusError",
          "code": -1,
          "description": "\(underlying)",
        ]
      case .other(let underlying):
        return [
          "type": "failure",
          "kind": "statusError",
          "code": -1,
          "description": underlying.map { "\($0)" } ?? "Unknown error",
        ]
      }
    } catch {
      return [
        "type": "failure",
        "kind": "statusError",
        "code": -1,
        "description": error.localizedDescription,
      ]
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
    // Re-send the current init state so a listener attaching after a
    // transition is not stuck on the stale default.
    emitIsInitialised()
    return nil
  }
  
  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    eventEmitter.setEventSink(nil)
    return nil
  }

  // MARK: - SDK lifecycle helpers

  /// Builds the SSO `ConnectionMode`, wiring the `loginRequired` / `modifyUser`
  /// callbacks. Unrecognized `appManagedFields` wire strings are logged loudly
  /// so a future Dart-side rename does not silently turn into "Octopus manages
  /// this field" (the AVATAR/PICTURE bug that hid here pre-1.11.0).
  private func makeSSOConnectionMode(_ appManagedFields: [String]) -> ConnectionMode {
    let profileFields: Set<ConnectionMode.SSOConfiguration.ProfileField> = Set(appManagedFields.compactMap { fieldName in
      switch fieldName {
      case "NICKNAME": return .nickname
      case "PICTURE": return .picture
      case "BIO": return .bio
      default:
        NSLog("[OctopusSDK] Unknown appManagedFields entry '\(fieldName)' — dropped. Expected one of NICKNAME, PICTURE, BIO.")
        return nil
      }
    })

    if !profileFields.isEmpty {
      // With app managed fields
      return .sso(.init(
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
    } else {
      // Without app managed fields
      return .sso(.init(
        loginRequired: {
          print("iOS: SDK loginRequired callback triggered")
          self.eventEmitter.emitLoginRequired()
        }
      ))
    }
  }

  /// Creates (or re-creates) the SDK instance. Disconnects any existing
  /// instance and clears the observers before reinitializing, then re-attaches
  /// them.
  private func setup(apiKey: String, connectionMode: ConnectionMode, configuration: OctopusSDK.Configuration) throws {
    // Always reset previous instance to avoid stale state.
    if let existing = octopus {
      existing.disconnectUser()
    }
    cancellables.removeAll()

    octopus = try OctopusSDK(
      apiKey: apiKey,
      connectionMode: connectionMode,
      configuration: configuration
    )

    guard let octopus else { throw NSError(domain: "octopus", code: -20) }
    OctopusSDKFlutterPlugin.shared?.octopus = octopus
    startObservingNotSeenNotificationsCount()
    startObservingHasAccessToCommunity()
    startObservingProfile()
    startObservingGroups()
    startObservingConnectionState()
    startObservingEvents()
    // Forward the SDK-level group-access-denied callback to Dart via the event
    // channel; the Dart consumer opts in via setGroupAccessDeniedCallback.
    octopus.set(groupAccessDeniedCallback: { [weak self] groupId in
      self?.sendEvent("groupAccessDenied", data: ["groupId": groupId])
    })
    // Forward the bridge "view object" button tap to Dart; the Dart consumer
    // opts in via setNavigateToClientObjectCallback. iOS exposes this as a
    // global callback (Android wires it per embedded view).
    octopus.set(displayClientObjectCallback: { [weak self] objectId in
      self?.sendEvent("navigateToClientObject", data: ["objectId": objectId])
    })
    emitIsInitialised()
  }

  /// Creates the SDK in SSO mode. Shared by `initialize` (and the
  /// `switchCommunity` cold-start fallback).
  private func setupSSO(apiKey: String, appManagedFields: [String], configuration: OctopusSDK.Configuration) throws {
    try setup(apiKey: apiKey, connectionMode: makeSSOConnectionMode(appManagedFields), configuration: configuration)
  }

  /// Creates the SDK in Octopus Auth mode. Shared by `initializeOctopusAuth`
  /// (and the `switchCommunityOctopusAuth` cold-start fallback).
  private func setupOctopusAuth(apiKey: String, deepLink: String?, configuration: OctopusSDK.Configuration) throws {
    try setup(apiKey: apiKey, connectionMode: .octopus(deepLink: deepLink), configuration: configuration)
  }

  /// Switches to a different community. Uses the native
  /// `OctopusSDK.switchCommunity` (clears cached data, preserves the
  /// notification device token). When the SDK is not yet initialized, the
  /// native call is unavailable, so this initializes instead — mirroring
  /// Android's `switchCommunity`, which is safe to call when uninitialized.
  private func performSwitchCommunity(
    apiKey: String,
    connectionMode: ConnectionMode,
    configuration: OctopusSDK.Configuration,
    result: @escaping FlutterResult
  ) {
    guard let octopus else {
      do {
        try setup(apiKey: apiKey, connectionMode: connectionMode, configuration: configuration)
        result(nil)
      } catch {
        result(FlutterError(code: "SWITCH_COMMUNITY_ERROR", message: error.localizedDescription, details: nil))
      }
      return
    }
    Task {
      do {
        try await octopus.switchCommunity(
          apiKey: apiKey,
          connectionMode: connectionMode,
          configuration: configuration
        )
        // The native switchCommunity reuses the same instance and re-registers
        // its publishers, so the existing observers stay attached; just refresh
        // the init-state snapshot.
        emitIsInitialised()
        result(nil)
      } catch {
        result(FlutterError(code: "SWITCH_COMMUNITY_ERROR", message: error.localizedDescription, details: nil))
      }
    }
  }

  /// Emits the current init state. iOS has no native `isInitialisedFlow`; the
  /// presence of an `octopus` instance is the source of truth.
  private func emitIsInitialised() {
    sendEvent("isInitialisedChanged", data: ["isInitialised": octopus != nil])
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

  private func startObservingProfile() {
    guard let octopus else { return }
    octopus.$profile
      .receive(on: DispatchQueue.main)
      .sink { [weak self] profile in
        self?.sendEvent(
          "profileChanged",
          data: ["profile": profile.map { ["entitlements": Array($0.entitlements)] } as Any]
        )
      }
      .store(in: &cancellables)
  }

  private func startObservingGroups() {
    guard let octopus else { return }
    octopus.$groups
      .receive(on: DispatchQueue.main)
      .sink { [weak self] groups in
        self?.sendEvent(
          "groupsChanged",
          data: [
            "groups": groups.map {
              [
                "id": $0.id,
                "name": $0.name,
                "isFollowed": $0.isFollowed,
                "canChangeFollowStatus": $0.canChangeFollowStatus,
                "canAccess": $0.canAccess,
                "canCreateChildren": $0.canCreateChildren,
              ]
            },
          ]
        )
      }
      .store(in: &cancellables)
  }

  /// Derives `connectionStateChanged` from `octopus.$profile`: the iOS public
  /// SDK has no dedicated `ConnectionState` publisher, so the profile publisher
  /// is the source — "profile is set → connected; profile is nil → not
  /// connected" — and the guest flag is read from `OctopusProfile.isGuest`
  /// (exposed on the iOS public surface since native SDK 1.12.6). Both the
  /// connected and guest signals now match Android; see `OctopusConnected.isGuest`.
  private func startObservingConnectionState() {
    guard let octopus else { return }
    octopus.$profile
      .receive(on: DispatchQueue.main)
      .sink { [weak self] profile in
        if let profile {
          self?.sendEvent(
            "connectionStateChanged",
            data: ["connected": true, "isGuest": profile.isGuest]
          )
        } else {
          self?.sendEvent(
            "connectionStateChanged",
            data: ["connected": false]
          )
        }
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
        "topicId": context.groupId,
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
    case .groupFollowingChanged(let context):
      return [
        "type": "groupFollowingChanged",
        "groupId": context.groupId,
        "followed": context.followed
      ]
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

  /// Decodes the wire reaction map sent by Dart into an `OctopusReactionKind`,
  /// or `nil` (remove reaction). The inverse of the Dart `toWire()`.
  ///
  /// An `unknown` kind is reconstructed as `.unknown(serverValue)`; the SDK
  /// rejects it with `OctopusSetReactionError.unknownReaction`.
  private func deserializeReactionKind(_ map: [String: Any]?) -> OctopusReactionKind? {
    guard let map = map else { return nil }
    switch map["kind"] as? String {
    case "heart": return .heart
    case "joy": return .joy
    case "mouthOpen": return .mouthOpen
    case "clap": return .clap
    case "cry": return .cry
    case "rage": return .rage
    default: return .unknown((map["serverValue"] as? String) ?? "")
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

  // MARK: - Bridge token round-trip

  /// Runs the native→Dart bridge-token round-trip for [requestId]: parks a
  /// continuation, emits a `bridgeTokenRequest` event carrying the
  /// [fingerprint], and awaits the matching `provideBridgeToken` reply (the
  /// host returns `nil` when no signature is available). Returns the signed
  /// token, or `nil`.
  ///
  /// Shared by `fetchOrCreateClientObjectRelatedPost` and the create-post
  /// editor's bridge-share signer (`OctopusCreatePostPresenter`), mirroring
  /// Android's process-shared `requestBridgeToken`. The continuations map is
  /// keyed by [requestId] and the Dart side mints a globally-unique id per
  /// invocation, so the two call sites never collide.
  func requestBridgeToken(requestId: String, fingerprint: String) async -> String? {
    return await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
      DispatchQueue.main.async { [weak self] in
        guard let self else {
          continuation.resume(returning: nil)
          return
        }
        // Defensive: if a stale continuation is still parked for this id (the
        // SDK re-invoked the block within one call), resume it with nil before
        // overwriting so it can never leak or hang.
        self.bridgeTokenContinuations[requestId]?.resume(returning: nil)
        self.bridgeTokenContinuations[requestId] = continuation
        self.sendEvent("bridgeTokenRequest", data: ["requestId": requestId, "fingerprint": fingerprint])
      }
    }
  }

  // MARK: - Bridge (client object related post)

  /// Decodes the wire `clientPost` map into a native `ClientPost`.
  private static func decodeClientPost(_ map: [String: Any]) throws -> ClientPost {
    guard let objectId = map["objectId"] as? String else {
      throw NSError(domain: "octopus", code: -30,
                    userInfo: [NSLocalizedDescriptionKey: "objectId is required"])
    }
    guard let text = map["text"] as? String else {
      throw NSError(domain: "octopus", code: -31,
                    userInfo: [NSLocalizedDescriptionKey: "text is required"])
    }
    let attachment = (map["attachment"] as? [String: Any]).flatMap { decodeAttachment($0) }
    return ClientPost(
      clientObjectId: objectId,
      groupId: map["groupId"] as? String,
      text: text,
      catchPhrase: map["catchPhrase"] as? String,
      attachment: attachment,
      viewClientObjectButtonText: map["viewObjectButtonText"] as? String
    )
  }

  /// Maps the wire attachment (`localImage` bytes / `remoteImage` url) onto the
  /// native `ClientPost.Attachment`. The Dart `remoteImage` discriminator maps
  /// to iOS `distantImage`.
  private static func decodeAttachment(_ map: [String: Any]) -> ClientPost.Attachment? {
    switch map["type"] as? String {
    case "remoteImage":
      guard let urlString = map["url"] as? String, let url = URL(string: urlString) else { return nil }
      return .distantImage(url)
    case "localImage":
      guard let typed = map["bytes"] as? FlutterStandardTypedData else { return nil }
      return .localImage(typed.data)
    default:
      return nil
    }
  }

  private static func serializeOctopusPost(_ post: any OctopusPost) -> [String: Any] {
    return [
      "id": post.id,
      "commentCount": post.commentCount,
      "viewCount": post.viewCount,
      "reactions": post.reactions.map {
        ["reactionKind": reactionKindToWire($0.reaction), "count": $0.count]
      },
      "userReactionKind": post.userReaction.map { reactionKindToWire($0) } as Any,
    ]
  }

  /// Serializes an `OctopusReactionKind` into the `{kind, serverValue?}` wire
  /// map the Dart `OctopusReactionKind.fromWire` expects.
  private static func reactionKindToWire(_ kind: OctopusReactionKind) -> [String: Any] {
    switch kind {
    case .heart: return ["kind": "heart"]
    case .joy: return ["kind": "joy"]
    case .mouthOpen: return ["kind": "mouthOpen"]
    case .clap: return ["kind": "clap"]
    case .cry: return ["kind": "cry"]
    case .rage: return ["kind": "rage"]
    case .unknown(let value): return ["kind": "unknown", "serverValue": value]
    @unknown default: return ["kind": "unknown", "serverValue": ""]
    }
  }

  /// Maps the iOS `ClientPostError` onto the shared OctopusResult failure wire.
  /// No-network routes through the connection branch; server/other/validation
  /// errors flow through `invalidArguments`. iOS does not expose the typed
  /// validation kind publicly (`ValidationError`'s fields are internal), so
  /// each validation error surfaces as a generic `other` carrying its
  /// description — Android produces the fine-grained typed errors.
  private static func encodeClientPostError(_ e: ClientPostError) -> [String: Any] {
    switch e {
    case .noNetwork:
      return ["type": "failure", "kind": "noNetwork"]
    case .serverError:
      return ["type": "failure", "kind": "invalidArguments",
              "errors": [["type": "other", "message": "Server error"]]]
    case .other(let underlying):
      return ["type": "failure", "kind": "invalidArguments",
              "errors": [["type": "other", "message": underlying.map { "\($0)" } ?? "Client post error"]]]
    case .validation(let validationErrors):
      let errors: [[String: Any]] = validationErrors.map {
        ["type": "other", "message": $0.debugDescription]
      }
      return ["type": "failure", "kind": "invalidArguments",
              "errors": errors.isEmpty ? [["type": "other", "message": "Validation error"]] : errors]
    @unknown default:
      return ["type": "failure", "kind": "invalidArguments",
              "errors": [["type": "other", "message": "Client post error"]]]
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
    case .mainFeed(let context):
      return [
        "type": "mainFeed",
        "feedId": context.feedId
      ]
    case .groups:
      return ["type": "groups"]
    case .groupDetail(let context):
      let sourceString: String
      switch context.source {
      case .clientApp:
        sourceString = "bridge"
      case .community:
        sourceString = "community"
      }
      return [
        "type": "groupDetail",
        "groupId": context.groupId,
        "source": sourceString
      ]
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

private extension OctopusSyncFollowGroup.Status {
  func toWireValue() -> String {
    switch self {
    case .applied:           return "applied"
    case .skipped:           return "skipped"
    case .groupNotFound:     return "group_not_found"
    case .notFollowable:     return "not_followable"
    case .notUnfollowable:   return "not_unfollowable"
    case .alreadyFollowed:   return "already_followed"
    case .alreadyUnfollowed: return "already_unfollowed"
    case .unknownError:      return "unknown_error"
    @unknown default:        return "unknown_error"
    }
  }
}
