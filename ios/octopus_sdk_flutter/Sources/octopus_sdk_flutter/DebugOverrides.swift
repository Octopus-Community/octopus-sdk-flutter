import Foundation
// `debugOverrideProfileFieldsLock` / `debugOverrideContentOptions` /
// `debugOverrideTermsAcceptanceMode` on `OctopusSDK` are hidden behind this
// SPI (`Sources/Octopus/OctopusSDK.swift`) — only an `@_spi` import can see
// them, a plain `import Octopus` cannot. `Octopus` itself is available on
// both the CocoaPods and SPM integration paths, so this import is
// unconditional.
@_spi(OctopusInternalTesting) import Octopus

// `ProfileFieldsLock` / `ContentOptions` / `TermsAcceptanceMode` (the
// parameter types the three methods above take, in their native SPI
// signatures) and `OctopusSDKCore` are declared in `OctopusCore`, not in
// `Octopus`. octopus-sdk-swift declares only two SwiftPM products, `Octopus`
// and `OctopusUI`; `OctopusCore` is an internal target that `Octopus` imports
// without re-exporting. No declared product carries these types, so the
// import below is the only way to build the real implementation, and making
// it reachable through a product is an upstream change.
//
// - CocoaPods: `OctopusCore` is a first-class published pod
//   (`OctopusCommunityCore`, module name `OctopusCore`) declared in
//   `octopus_sdk_flutter.podspec`, so this import is a declared dependency.
// - SPM (this plugin's own `Package.swift`): the import is not backed by a
//   declared product. It still resolves through the module search path the
//   `Octopus` product brings along: the Integration `spm` leg on Flutter
//   3.44.5 printed a temporary `#error` probe behind
//   `#if SWIFT_PACKAGE && canImport(OctopusCore)`, confirming that the real
//   implementation is selected. If a toolchain stops exposing it, `canImport`
//   turns false and the stub compiles.
//
// `#if canImport(OctopusCore)` keeps both outcomes compiling: the real
// implementation where the module is reachable, otherwise a stub that
// reports "unsupported" so the plugin answers `UNSUPPORTED_PLATFORM` instead
// of failing the build.
#if canImport(OctopusCore)
import OctopusCore
#endif

/// Outcome of `OctopusDebugOverridesBridge.debugGetCommunityConfig`, mapped to the channel reply by
/// the plugin: a config map (or `nil` before the first fetch), an unsupported integration path, or a
/// supported path whose native core could not be reached.
enum OctopusDebugCommunityConfigRead {
  /// The effective config as a wire map, or `nil` while none has been fetched yet.
  case config([String: Any]?)
  /// This build cannot reach `OctopusCore`, so it cannot read the config.
  case unsupported
  /// CocoaPods, but the `Mirror` lookup of the SDK core failed (a native release renamed it).
  case unreachable
}

/// Bridges the `debugOverride*` QA affordances and the `debugGetCommunityConfig` read to the native
/// SPI. Isolated to this file so it is the only place conditionally importing `OctopusCore` — see
/// the file-level comment above for why the import itself must stay conditional, and note also
/// that `OctopusCore` declares its own
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

  /// Applies verbatim wordings, or clears with nil, without changing acceptance mode.
  @discardableResult
  static func debugOverrideConsentTexts(_ octopus: OctopusSDK, textsMap: [String: Any]?) async -> Bool {
    await octopus.debugOverrideConsentTexts(parseConsentTexts(textsMap))
    return true
  }

  /// Reads the community config the native SDK currently holds (backend GetConfig + any local
  /// `debugOverride*`), as the wire map `OctopusDebugCommunityConfig.fromWire` decodes. `config` is
  /// `nil` while no config has been fetched yet.
  ///
  /// `OctopusSDK.core` is `package`-visible (reserved for the native UI lib), so the read goes
  /// through `Mirror` — the same route the React Native bridge takes. Acceptable for a debug
  /// affordance, never for shipping API. The read is `.unreachable` if a native release renames
  /// the stored property, so the caller surfaces a typed error instead of a silent `nil`.
  @MainActor
  static func debugGetCommunityConfig(_ octopus: OctopusSDK) -> OctopusDebugCommunityConfigRead {
    guard
      let core = Mirror(reflecting: octopus).children
        .first(where: { $0.label == "core" })?.value as? OctopusSDKCore
    else {
      NSLog("[OctopusSDK] debugGetCommunityConfig: could not reach the SDK core through Mirror.")
      return .unreachable
    }
    guard let config = core.configRepository.communityConfig else { return .config(nil) }
    // The Android enum spelling, so both bridges send one wire format (the inverse of
    // `parseTermsAcceptanceMode` below).
    let mode: String
    switch config.termsAcceptanceMode {
    case .implicit: mode = "IMPLICIT"
    case .explicitMultiCheckbox: mode = "EXPLICIT_MULTI_CHECKBOX"
    case .explicitSingleCheckbox: mode = "EXPLICIT_SINGLE_CHECKBOX"
    }
    return .config([
      "exposeClientUserId": config.exposeClientUserId,
      "forceLoginOnStrongActions": config.forceLoginOnStrongActions,
      "displayAccountAge": config.displayAccountAge,
      "forceNicknameChoice": config.forceNicknameChoice,
      "consentTexts": serializeConsentTexts(config.consentTexts) as Any? ?? NSNull(),
      "termsAcceptanceMode": mode,
    ])
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
  /// creation flag falls back to `true`; optional tap flags fall back to `false`.
  static func parseContentOptions(_ map: [String: Any]?) -> ContentOptions? {
    guard let map else { return nil }
    let post = map["post"] as? [String: Any]
    let comment = map["comment"] as? [String: Any]
    let reply = map["reply"] as? [String: Any]
    return ContentOptions(
      post: ContentOptions.PostOptions(
        enablePictures: post?["enablePictures"] as? Bool ?? true,
        enablePolls: post?["enablePolls"] as? Bool ?? true,
        textRequired: post?["textRequired"] as? Bool ?? true,
        imageTapOpensPost: post?["imageTapOpensPost"] as? Bool ?? false,
        groupNameTapOpensGroup: post?["groupNameTapOpensGroup"] as? Bool ?? false
      ),
      comment: ContentOptions.CommentOptions(
        enablePictures: comment?["enablePictures"] as? Bool ?? true
      ),
      reply: ContentOptions.ReplyOptions(
        enablePictures: reply?["enablePictures"] as? Bool ?? true
      )
    )
  }

  static func parseConsentTexts(_ map: [String: Any]?) -> OctopusCore.ConsentTexts? {
    guard let map else { return nil }
    switch map["mode"] as? String {
    case "implicit": return .implicit(notice: map["notice"] as? String)
    case "multiCheckbox": return .multiCheckbox(
      termsLabel: map["termsLabel"] as? String,
      privacyLabel: map["privacyLabel"] as? String,
      rulesLabel: map["rulesLabel"] as? String
    )
    case "singleCheckbox": return .singleCheckbox(
      label: map["label"] as? String, belowText: map["belowText"] as? String
    )
    default: return nil
    }
  }

  static func serializeConsentTexts(_ texts: OctopusCore.ConsentTexts?) -> [String: Any]? {
    func wire(_ text: String?) -> Any { text as Any? ?? NSNull() }
    switch texts {
    case nil: return nil
    case .implicit(let notice): return ["mode": "implicit", "notice": wire(notice)]
    case .multiCheckbox(let termsLabel, let privacyLabel, let rulesLabel):
      return ["mode": "multiCheckbox", "termsLabel": wire(termsLabel),
              "privacyLabel": wire(privacyLabel), "rulesLabel": wire(rulesLabel)]
    case .singleCheckbox(let label, let belowText):
      return ["mode": "singleCheckbox", "label": wire(label), "belowText": wire(belowText)]
    }
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
  // `OctopusCore` is not reachable in this build (see the file-level
  // comment) — fall back to a no-op that reports "unsupported" so the caller
  // can surface a typed `FlutterError` instead of silently doing nothing.
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

  @discardableResult
  static func debugOverrideConsentTexts(_ octopus: OctopusSDK, textsMap: [String: Any]?) async -> Bool {
    false
  }

  @MainActor
  static func debugGetCommunityConfig(_ octopus: OctopusSDK) -> OctopusDebugCommunityConfigRead {
    .unsupported
  }
#endif

  /// A nullable boolean needs no Core type, so both integration paths support this SPI.
  static func debugOverrideForceNicknameChoice(_ octopus: OctopusSDK, enabled: Bool?) async {
    await octopus.debugOverrideForceNicknameChoice(enabled)
  }

  /// Applies (or clears, with `nil`) the `debugOverrideExposeClientUserId` override — the Unified
  /// Profile activation flag. Outside the `#if` on purpose: its parameter is a plain `Bool?`, so it
  /// needs no `OctopusCore` type and is supported on both integration paths (CocoaPods and SPM).
  /// It still lives in this file because the `@_spi(OctopusInternalTesting)` import it needs is here.
  static func debugOverrideExposeClientUserId(_ octopus: OctopusSDK, enabled: Bool?) async {
    await octopus.debugOverrideExposeClientUserId(enabled)
  }
}
