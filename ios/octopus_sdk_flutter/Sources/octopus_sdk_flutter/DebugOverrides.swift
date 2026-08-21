import Foundation
// `debugOverrideProfileFieldsLock` / `debugOverrideContentOptions` /
// `debugOverrideTermsAcceptanceMode` on `OctopusSDK` are hidden behind this
// SPI (`Sources/Octopus/OctopusSDK.swift`) — only an `@_spi` import can see
// them, a plain `import Octopus` cannot. `Octopus` itself is available on
// both the CocoaPods and SPM integration paths, so this import is
// unconditional.
@_spi(OctopusInternalTesting) import Octopus

// `ProfileFieldsLock` / `ContentOptions` / `TermsAcceptanceMode` (the
// parameter types the three methods above need to construct) are declared
// in `OctopusCore`, not in `Octopus`. Whether that module is reachable here
// depends on the iOS integration path:
//
// - CocoaPods: `OctopusCore` is not a Swift Package "product" of
//   octopus-sdk-swift, but it *is* a first-class published pod
//   (`OctopusCommunityCore`) that `OctopusCommunity` already pulls in
//   transitively — CocoaPods has no concept of "products", so declaring
//   `OctopusCommunityCore` as a dependency in `octopus_sdk_flutter.podspec`
//   is enough to `import OctopusCore` directly. Verified by building
//   `example/` with `flutter config --no-enable-swift-package-manager` +
//   `pod install` + `flutter build ios --simulator`: it compiles.
// - SPM (this plugin's own `Package.swift`): `OctopusCore` is a plain
//   internal `.target` of octopus-sdk-swift, never declared under that
//   package's `products:`. A remote package dependency can only see a
//   consumer's declared products, so `OctopusCore` is NOT reachable here —
//   confirmed by the same build with `flutter config
//   --enable-swift-package-manager` instead: `error: no such module
//   'OctopusCore'`. This is the genuine, narrower version of the original
//   stub's blocker: only the parameter *types* are unreachable via SPM, not
//   the three `debugOverride*` entry points themselves (those are on
//   `OctopusSDK` in the `Octopus` module, reachable on both paths).
//
// `#if canImport(OctopusCore)` lets each integration path compile its own
// half: CocoaPods gets the real implementation below, SPM falls back to the
// typed-error stub, without one path's outcome regressing the other's.
#if canImport(OctopusCore)
import OctopusCore
#endif

/// Bridges the three `debugOverride*` QA affordances to the native SPI. Isolated to this file so it
/// is the only place conditionally importing `OctopusCore` — see the file-level comment above for
/// why the import itself must stay conditional, and note also that `OctopusCore` declares its own
/// `ConnectionMode` / `ClientPost` / `CustomEvent` (and likely others) that collide by *name* with
/// the public `Octopus` module's types of the same name, which `OctopusSDKFlutterPlugin.swift`
/// references unqualified everywhere. A Swift `import` is file-scoped, so confining it here also
/// keeps every other file's unqualified lookups resolving to `Octopus` only.
enum OctopusDebugOverridesBridge {
#if canImport(OctopusCore)
  /// Applies (or clears) the `debugOverrideProfileFieldsLock` override. `lockMap` is the wire map
  /// under the `lock` key (`nickname`/`avatar`/`bio` strings), or `nil` to clear the override.
  /// Returns `true`: this integration path supports the override.
  @discardableResult
  static func debugOverrideProfileFieldsLock(_ octopus: OctopusSDK, lockMap: [String: Any]?) async -> Bool {
    await octopus.debugOverrideProfileFieldsLock(parseProfileFieldsLock(lockMap))
    return true
  }

  /// Applies (or clears) the `debugOverrideContentOptions` override. `optionsMap` is the wire map
  /// under the `options` key, or `nil` to clear the override. Returns `true`: this integration path
  /// supports the override.
  @discardableResult
  static func debugOverrideContentOptions(_ octopus: OctopusSDK, optionsMap: [String: Any]?) async -> Bool {
    await octopus.debugOverrideContentOptions(parseContentOptions(optionsMap))
    return true
  }

  /// Applies (or clears) the `debugOverrideTermsAcceptanceMode` override. `mode` is the wire value
  /// under the `mode` key, or `nil` to clear the override. Returns `true`: this integration path
  /// supports the override.
  @discardableResult
  static func debugOverrideTermsAcceptanceMode(_ octopus: OctopusSDK, mode: String?) async -> Bool {
    await octopus.debugOverrideTermsAcceptanceMode(parseTermsAcceptanceMode(mode))
    return true
  }

  /// Parses the `lock` wire map into a native `ProfileFieldsLock`. `nil` clears the override.
  /// Fails closed: if any of the three fields carries a value this bridge does not recognize, the
  /// whole override is dropped (no lock applied) rather than defaulting that field to the most
  /// permissive state. Mirrors the Android Kotlin bridge's `parseProfileFieldsLock`.
  private static func parseProfileFieldsLock(_ map: [String: Any]?) -> ProfileFieldsLock? {
    guard let map else { return nil }
    func state(_ key: String) -> ProfileFieldLockState? {
      switch map[key] as? String {
      case "EDITABLE": return .editable
      case "READ_ONLY": return .readOnly
      case "DISABLED": return .disabled
      default:
        NSLog(
          "[OctopusSDK] Unknown ProfileFieldsLock.\(key) entry "
            + "'\(map[key] ?? "nil")' — dropping the whole override (no lock applied). "
            + "Expected one of EDITABLE, READ_ONLY, DISABLED."
        )
        return nil
      }
    }
    guard let nickname = state("nickname"),
          let avatar = state("avatar"),
          let bio = state("bio")
    else {
      return nil
    }
    return ProfileFieldsLock(nickname: nickname, avatar: avatar, bio: bio)
  }

  /// Parses the `options` wire map into a native `ContentOptions`. `nil` clears the override.
  /// Mirrors the Android Kotlin bridge's `parseContentOptions`: a missing sub-map or a wrong-typed
  /// flag falls back to `true`, matching both the native default and the Dart default.
  private static func parseContentOptions(_ map: [String: Any]?) -> ContentOptions? {
    guard let map else { return nil }
    let post = map["post"] as? [String: Any]
    let comment = map["comment"] as? [String: Any]
    let reply = map["reply"] as? [String: Any]
    return ContentOptions(
      post: ContentOptions.PostOptions(
        enablePictures: post?["enablePictures"] as? Bool ?? true,
        enablePolls: post?["enablePolls"] as? Bool ?? true
      ),
      comment: ContentOptions.CommentOptions(
        enablePictures: comment?["enablePictures"] as? Bool ?? true
      ),
      reply: ContentOptions.ReplyOptions(
        enablePictures: reply?["enablePictures"] as? Bool ?? true
      )
    )
  }

  /// Parses the `mode` wire value into a native `TermsAcceptanceMode`. `nil` clears the override.
  /// Mirrors the Android Kotlin bridge's `parseTermsAcceptanceMode`: an unrecognized value is
  /// dropped (no override applied) rather than defaulted.
  private static func parseTermsAcceptanceMode(_ value: String?) -> TermsAcceptanceMode? {
    switch value {
    case "IMPLICIT": return .implicit
    case "EXPLICIT_MULTI_CHECKBOX": return .explicitMultiCheckbox
    case "EXPLICIT_SINGLE_CHECKBOX": return .explicitSingleCheckbox
    case nil: return nil
    default:
      NSLog(
        "[OctopusSDK] Unknown TermsAcceptanceMode value '\(value ?? "nil")' — dropped "
          + "(no override applied). Expected one of IMPLICIT, EXPLICIT_MULTI_CHECKBOX, "
          + "EXPLICIT_SINGLE_CHECKBOX."
      )
      return nil
    }
  }
#else
  // `OctopusCore` is not reachable on this integration path (see the
  // file-level comment) — fall back to a no-op that reports "unsupported"
  // so the caller can surface a typed `FlutterError` instead of silently
  // doing nothing.
  @discardableResult
  static func debugOverrideProfileFieldsLock(_ octopus: OctopusSDK, lockMap: [String: Any]?) async -> Bool {
    false
  }

  @discardableResult
  static func debugOverrideContentOptions(_ octopus: OctopusSDK, optionsMap: [String: Any]?) async -> Bool {
    false
  }

  @discardableResult
  static func debugOverrideTermsAcceptanceMode(_ octopus: OctopusSDK, mode: String?) async -> Bool {
    false
  }
#endif
}
