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

    let info = buildCreatePostInfo(from: args?["prefilledPost"] as? [String: Any])
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

  /// Builds the native create-post entry info from the Flutter `prefilledPost`
  /// map. iOS validates the prefilled image eagerly (decode/size/ratio) — unlike
  /// Android/Flutter, which defer image checks to the editor — so if the full
  /// payload is rejected we retry without the image, then fall back to an empty
  /// editor, rather than dropping the whole prefill.
  static func buildCreatePostInfo(from map: [String: Any]?) -> OctopusInitialScreen.CreatePostScreenInfo {
    guard let map else { return .init(prefilledPost: nil) }
    let text = map["text"] as? String
    let topicId = map["topicId"] as? String
    let imageData = (map["image"] as? FlutterStandardTypedData)?.data

    var cta: OctopusPrefilledPost.CTA? = nil
    if let ctaMap = map["cta"] as? [String: Any],
       let urlStr = ctaMap["url"] as? String, let url = URL(string: urlStr),
       let label = ctaMap["label"] as? String {
      cta = try? OctopusPrefilledPost.CTA(url: url, label: label)
    }

    if let prefill = try? OctopusPrefilledPost(text: text, image: imageData, topicId: topicId, cta: cta) {
      return .init(prefilledPost: prefill)
    }
    if let prefill = try? OctopusPrefilledPost(text: text, image: nil, topicId: topicId, cta: cta) {
      return .init(prefilledPost: prefill)
    }
    return .init(prefilledPost: nil)
  }

  private static func buildTheme(from dict: [String: Any]?) -> (OctopusTheme?, String?) {
    guard let dict else { return (nil, nil) }
    let main = (dict["primaryMain"] as? NSNumber).map { OctopusSDKFlutterPlugin.uiColorFromARGBInt($0.intValue) }
    let low = (dict["primaryLowContrast"] as? NSNumber).map { OctopusSDKFlutterPlugin.uiColorFromARGBInt($0.intValue) }
    let high = (dict["primaryHighContrast"] as? NSNumber).map { OctopusSDKFlutterPlugin.uiColorFromARGBInt($0.intValue) }
    let onPrimary = (dict["onPrimary"] as? NSNumber).map { OctopusSDKFlutterPlugin.uiColorFromARGBInt($0.intValue) }
    let logoBase64 = dict["logoBase64"] as? String
    let themeMode = dict["themeMode"] as? String
    let f1 = (dict["fontSizeTitle1"] as? NSNumber)?.intValue ?? 26
    let f2 = (dict["fontSizeTitle2"] as? NSNumber)?.intValue ?? 20
    let f3 = (dict["fontSizeBody1"] as? NSNumber)?.intValue ?? 17
    let f4 = (dict["fontSizeBody2"] as? NSNumber)?.intValue ?? 14
    let f5 = (dict["fontSizeCaption1"] as? NSNumber)?.intValue ?? 12
    let f6 = (dict["fontSizeCaption2"] as? NSNumber)?.intValue ?? 10

    let hasTheme = main != nil || low != nil || high != nil || onPrimary != nil || logoBase64 != nil ||
      themeMode != nil || f1 != 26 || f2 != 20 || f3 != 17 || f4 != 14 || f5 != 12 || f6 != 10
    guard hasTheme else { return (nil, themeMode) }

    let theme = OctopusSDKFlutterPlugin.buildTheme(
      main: main ?? .systemBlue,
      low: low ?? UIColor.systemBlue.withAlphaComponent(0.2),
      high: high ?? .white,
      onPrimary: onPrimary ?? .white,
      logoBase64: logoBase64,
      fontSizeTitle1: f1, fontSizeTitle2: f2, fontSizeBody1: f3,
      fontSizeBody2: f4, fontSizeCaption1: f5, fontSizeCaption2: f6,
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
