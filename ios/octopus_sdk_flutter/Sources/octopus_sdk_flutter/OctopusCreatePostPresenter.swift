import Foundation
import Flutter
import SwiftUI
import Octopus
import OctopusUI
import Combine

/// A UIHostingController that reports when it is dismissed (close button,
/// publish, or interactive swipe), so the Flutter method call can complete.
final class DismissReportingHostingController<Content: View>: UIHostingController<Content> {
  var onDismiss: (() -> Void)?
  private var reported = false

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    if (isBeingDismissed || isMovingFromParent || parent == nil), !reported {
      reported = true
      onDismiss?()
    }
  }
}

/// Error thrown by the bridge-share `sign` closure when the Dart
/// `bridgeShareTokenProvider` declines to sign (replies `null`). iOS
/// `OctopusPrefilledPost.sign` returns a non-optional `String`, so it has no
/// "proceed unsigned" channel — a `null` reply must surface as a throw, which
/// the native SDK maps to a server-call error and shows in the editor.
enum BridgeShareSignError: Error {
  case notSigned
}

/// Presents the native Octopus create-post editor MODALLY (full-screen), so the
/// editor runs in a real presentation context — `presentationMode.isPresented`
/// is true, which makes its close button appear and work and hides the inert
/// inline back chevron. Mirrors the Swift sample's `.sheet` integration.
enum OctopusCreatePostPresenter {

  static func present(args: [String: Any]?, result: @escaping FlutterResult) {
    guard let octopus = OctopusSDKFlutterPlugin.sharedOctopus else {
      result(FlutterError(code: "NOT_INITIALIZED",
                          message: "Call initialize() first", details: nil))
      return
    }

    let info = buildCreatePostInfo(from: args)
    let (theme, themeMode) = buildTheme(from: args)

    let screen = OctopusHomeScreen(octopus: octopus, initialScreen: .createPost(info))
    let root: AnyView
    if let theme {
      root = AnyView(screen.environment(\.octopusTheme, theme)
        .preferredColorScheme(themeMode == "dark" ? .dark : themeMode == "light" ? .light : nil))
    } else {
      root = AnyView(screen
        .preferredColorScheme(themeMode == "dark" ? .dark : themeMode == "light" ? .light : nil))
    }

    guard let presenter = topViewController() else {
      result(FlutterError(code: "NO_PRESENTER",
                          message: "No view controller to present from", details: nil))
      return
    }

    let controller = DismissReportingHostingController(rootView: root)
    controller.modalPresentationStyle = .fullScreen
    var completed = false
    controller.onDismiss = {
      guard !completed else { return }
      completed = true
      result(nil)
    }
    presenter.present(controller, animated: true)
  }

  // MARK: - Helpers

  /// Builds the native create-post entry info from the Flutter
  /// `showCreatePostScreen` args. Reads the `prefilledPost` map plus the
  /// bridge-share signing keys (`bridgeTokenRequestId` /
  /// `hasBridgeShareTokenProvider`) that the Dart
  /// `showOctopusCreatePostScreen` adds when the host registered a
  /// `CreatePostScreenInfo.bridgeShareTokenProvider`.
  ///
  /// iOS validates the prefilled image eagerly (decode/size/ratio) — unlike
  /// Android/Flutter, which defer image checks to the editor — so if the full
  /// payload is rejected we retry without the image, then fall back to an empty
  /// editor, rather than dropping the whole prefill.
  ///
  /// The bridge-share signer lives on `OctopusPrefilledPost.sign` (iOS puts it
  /// on the prefilled post; Android/Flutter put it on `CreatePostScreenInfo`),
  /// so it is attached only when there is a prefilled post to carry it. That is
  /// also the only case that can carry a prefilled image — the sole content a
  /// pictures-off community requires a signature for — so an empty editor
  /// legitimately has nothing to sign.
  static func buildCreatePostInfo(from args: [String: Any]?) -> OctopusInitialScreen.CreatePostScreenInfo {
    let sign = buildBridgeShareSign(from: args)
    guard let map = args?["prefilledPost"] as? [String: Any] else {
      return .init(prefilledPost: nil)
    }
    let text = map["text"] as? String
    let topicId = map["topicId"] as? String
    let imageData = (map["image"] as? FlutterStandardTypedData)?.data

    var cta: OctopusPrefilledPost.CTA? = nil
    if let ctaMap = map["cta"] as? [String: Any],
       let urlStr = ctaMap["url"] as? String, let url = URL(string: urlStr),
       let label = ctaMap["label"] as? String {
      cta = try? OctopusPrefilledPost.CTA(url: url, label: label)
    }

    if let prefill = try? OctopusPrefilledPost(text: text, image: imageData, topicId: topicId, cta: cta, sign: sign) {
      return .init(prefilledPost: prefill)
    }
    if let prefill = try? OctopusPrefilledPost(text: text, image: nil, topicId: topicId, cta: cta, sign: sign) {
      return .init(prefilledPost: prefill)
    }
    return .init(prefilledPost: nil)
  }

  /// Builds the `OctopusPrefilledPost.sign` closure wired to the Dart side, or
  /// `nil` when the host registered no `bridgeShareTokenProvider`. When set,
  /// the native editor invokes it at publish time for a prefilled share
  /// carrying an image (community forbids member pictures); the closure runs
  /// the same native→Dart bridge-token round-trip as
  /// `fetchOrCreateClientObjectRelatedPost`, keyed by the Dart-supplied
  /// requestId (mirrors Android's `bridgeShareTokenProviderFromIntent`).
  ///
  /// **Shape adapter.** The Dart provider returns `String?` (`null` = declined
  /// to sign), but iOS `sign` returns a non-optional `String` and throws — it
  /// has no "proceed unsigned" channel. So when Dart replies `null` we throw
  /// `BridgeShareSignError.notSigned`: the native SDK maps this to a server-
  /// call error and keeps the editor open with an alert, rather than sending an
  /// unsigned/empty token. A pictures-off community would reject the unsigned
  /// image anyway, so the intended use case (host returns a real JWT) behaves
  /// identically to Android; the only divergence is the failure origin
  /// (client-side throw on iOS vs. server-side rejection on Android) when a
  /// host sets the provider yet returns `null`.
  private static func buildBridgeShareSign(
    from args: [String: Any]?
  ) -> (@Sendable (_ bridgeFingerprint: String) async throws -> String)? {
    guard let args,
          (args["hasBridgeShareTokenProvider"] as? Bool) == true,
          let requestId = args["bridgeTokenRequestId"] as? String
    else { return nil }
    // Capture the plugin weakly (the app-lifetime singleton owns the round-trip
    // continuations). The closure is assigned to a @Sendable type, so a weak
    // capture-list binding — immutable, captured by value — is the safe form.
    return { [weak plugin = OctopusSDKFlutterPlugin.shared] fingerprint in
      guard let plugin else { throw BridgeShareSignError.notSigned }
      guard let token = await plugin.requestBridgeToken(requestId: requestId, fingerprint: fingerprint) else {
        throw BridgeShareSignError.notSigned
      }
      return token
    }
  }

  private static func buildTheme(from dict: [String: Any]?) -> (OctopusTheme?, String?) {
    guard let dict else { return (nil, nil) }
    let main = (dict["primaryMain"] as? NSNumber).map { OctopusSDKFlutterPlugin.uiColorFromARGBInt($0.intValue) }
    let low = (dict["primaryLowContrast"] as? NSNumber).map { OctopusSDKFlutterPlugin.uiColorFromARGBInt($0.intValue) }
    let high = (dict["primaryHighContrast"] as? NSNumber).map { OctopusSDKFlutterPlugin.uiColorFromARGBInt($0.intValue) }
    let onPrimary = (dict["onPrimary"] as? NSNumber).map { OctopusSDKFlutterPlugin.uiColorFromARGBInt($0.intValue) }
    let background = (dict["background"] as? NSNumber).map { OctopusSDKFlutterPlugin.uiColorFromARGBInt($0.intValue) }
    let link = (dict["link"] as? NSNumber).map { OctopusSDKFlutterPlugin.uiColorFromARGBInt($0.intValue) }
    let fontFamily = dict["fontFamily"] as? String
    let fontWeight = (dict["fontWeight"] as? NSNumber)?.intValue
    let logoBase64 = dict["logoBase64"] as? String
    let themeMode = dict["themeMode"] as? String
    // All seven font slots stay optional, like the colors: `nil` is how a slot
    // asks for the SDK's own scaled default. See `buildTheme`.
    let f1 = (dict["fontSizeTitle1"] as? NSNumber)?.intValue
    let f2 = (dict["fontSizeTitle2"] as? NSNumber)?.intValue
    let f3 = (dict["fontSizeBody1"] as? NSNumber)?.intValue
    let f4 = (dict["fontSizeBody2"] as? NSNumber)?.intValue
    let f5 = (dict["fontSizeCaption1"] as? NSNumber)?.intValue
    let f6 = (dict["fontSizeCaption2"] as? NSNumber)?.intValue
    let navBarItem = (dict["fontSizeNavBarItem"] as? NSNumber)?.intValue

    // A plain presence test over every slot — `background`, `link`,
    // `fontFamily`, `fontWeight` and `navBarItem` included, since a host that
    // sets only one of them must still get a theme.
    let hasTheme = main != nil || low != nil || high != nil || onPrimary != nil || logoBase64 != nil ||
      background != nil || link != nil || fontFamily != nil || fontWeight != nil ||
      navBarItem != nil || themeMode != nil ||
      f1 != nil || f2 != nil || f3 != nil || f4 != nil || f5 != nil || f6 != nil
    guard hasTheme else { return (nil, themeMode) }

    // Optionals go through unsubstituted — see `buildTheme`: `nil` is how a slot
    // asks for the SDK's own default, and the embedded path does the same.
    let theme = OctopusSDKFlutterPlugin.buildTheme(
      main: main,
      low: low,
      high: high,
      onPrimary: onPrimary,
      background: background,
      link: link,
      logoBase64: logoBase64,
      fontFamily: fontFamily,
      fontWeight: fontWeight,
      fontSizeTitle1: f1, fontSizeTitle2: f2, fontSizeBody1: f3,
      fontSizeBody2: f4, fontSizeCaption1: f5, fontSizeCaption2: f6,
      fontSizeNavBarItem: navBarItem,
      themeMode: themeMode)
    return (theme, themeMode)
  }

  private static func topViewController() -> UIViewController? {
    let keyWindow = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    var top = keyWindow?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}
