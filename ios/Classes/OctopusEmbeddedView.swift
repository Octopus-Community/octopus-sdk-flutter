import Foundation
import Flutter
import SwiftUI
import Octopus
import OctopusUI
import Combine

// Custom view that wraps OctopusHomeScreen and handles navigation events.
// Migrated to the canonical 1.11 init (mainFeedNavBarTitle + notificationUserInfo).
struct OctopusHomeScreenWithCallback: View {
  let octopus: OctopusSDK
  let mainFeedNavBarTitle: OctopusMainFeedTitle?
  let mainFeedColoredNavBar: Bool
  let initialScreen: OctopusInitialScreen
  /// Which navigation container `OctopusHomeScreen` uses internally (1.12.2+).
  /// `.navigationStack` keeps sub-navigation pushes working when the SDK is
  /// hosted inside a Flutter modal route.
  let navigationMode: OctopusNavigationMode
  /// Optional host-driven leading nav-bar action (close / back) on the root
  /// screen (1.12.2+). The Flutter-hosted `UiKitView` is never presented via a
  /// native `.sheet` / `.fullScreenCover`, so the SDK paints no root dismiss
  /// button on its own; this lets the host request one whose tap is routed back
  /// to Dart as `backRequested` (→ `OctopusHomeScreen.onBack`).
  let navBarLeadingAction: OctopusNavBarLeadingAction?
  let notificationUserInfo: [AnyHashable: Any]?
  let onNavigateToLogin: () -> Void
  /// Extra bottom inset (points) the host wants reserved beyond the system
  /// safe area, so the native "Write a post" floats above the Flutter shell's
  /// own bottom chrome (e.g. a BottomNavigationBar). The previous hardcoded
  /// 10 pt was kept as the default to avoid changing existing layouts.
  let bottomSafeAreaInset: CGFloat

  var body: some View {
    OctopusHomeScreen(
      octopus: octopus,
      bottomSafeAreaInset: bottomSafeAreaInset,
      mainFeedNavBarTitle: mainFeedNavBarTitle,
      mainFeedColoredNavBar: mainFeedColoredNavBar,
      initialScreen: initialScreen,
      navigationMode: navigationMode,
      navBarLeadingAction: navBarLeadingAction,
      notificationUserInfo: .constant(notificationUserInfo)
    )
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OctopusNavigateToLogin"))) { _ in
      onNavigateToLogin()
    }
  }
}

/// Decodes the Dart `OctopusInitialScreen.toMap()` wire shape into the iOS
/// `OctopusInitialScreen` enum.
///
/// Unknown / malformed values fold to `.mainFeed`. Image bytes from the
/// `createPost` variant are intentionally dropped here: the embedded
/// initialScreen entry point is not the route hosts use to share an image
/// (`showOctopusCreatePostScreen` is). Hosts can still pass text, topicId,
/// and CTA through.
private func decodeInitialScreen(_ raw: Any?) -> OctopusInitialScreen {
  guard let map = raw as? [String: Any] else { return .mainFeed }
  switch map["type"] as? String {
  case "mainFeed", nil:
    return .mainFeed
  case "post":
    guard let postId = map["postId"] as? String,
          !postId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      NSLog("[OctopusSdkFlutter] initialScreen.post: missing/blank postId — falling back to mainFeed")
      return .mainFeed
    }
    return .post(.init(postId: postId))
  case "group":
    guard let groupId = map["groupId"] as? String,
          !groupId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      NSLog("[OctopusSdkFlutter] initialScreen.group: missing/blank groupId — falling back to mainFeed")
      return .mainFeed
    }
    return .group(.init(groupId: groupId))
  case "createPost":
    let prefilled = map["prefilledPost"] as? [String: Any]
    guard let prefilled = prefilled else {
      return .createPost(.init(prefilledPost: nil))
    }
    let text = (prefilled["text"] as? String)?.nilIfEmpty
    let topicId = (prefilled["topicId"] as? String)?.nilIfEmpty
    let cta: OctopusPrefilledPost.CTA?
    if let ctaMap = prefilled["cta"] as? [String: Any],
       let urlString = ctaMap["url"] as? String,
       let url = URL(string: urlString),
       let label = ctaMap["label"] as? String {
      cta = try? OctopusPrefilledPost.CTA(url: url, label: label)
    } else {
      cta = nil
    }
    let payload: OctopusPrefilledPost?
    do {
      payload = try OctopusPrefilledPost(text: text, image: nil, topicId: topicId, cta: cta)
    } catch {
      NSLog("[OctopusSdkFlutter] initialScreen.createPost: payload rejected (\(error)) — opening empty editor")
      payload = nil
    }
    return .createPost(.init(prefilledPost: payload))
  default:
    NSLog("[OctopusSdkFlutter] initialScreen: unknown type=\(map["type"] ?? "nil") — falling back to mainFeed")
    return .mainFeed
  }
}

private extension String {
  var nilIfEmpty: String? { isEmpty ? nil : self }
}

final class OctopusViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    return OctopusPlatformView(frame: frame, viewId: viewId, args: args)
  }
}

final class OctopusPlatformView: NSObject, FlutterPlatformView {
  private let container: SafeHostingContainerView

  init(frame: CGRect, viewId: Int64, args: Any?) {
    self.container = SafeHostingContainerView(args: args)
    self.container.frame = frame
    super.init()
  }

  func view() -> UIView { container }
}

private final class SafeHostingContainerView: UIView {

  private var hostingController: UIHostingController<AnyView>?
  private let args: Any?

  init(args: Any?) {
    self.args = args
    super.init(frame: .zero)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    guard window != nil else { return }

    // Avoid double initialization
    guard hostingController == nil else { return }

    initializeSwiftUIView()
  }

  private func initializeSwiftUIView() {
    guard let octopus = OctopusSDKFlutterPlugin.sharedOctopus else {
      addErrorLabel()
      return
    }

    var theme: OctopusTheme? = nil
    var navBarTitle: String? = nil
    var navBarPrimaryColor = false
    var themeMode: String? = nil
    var interceptUrls = false
    var notificationUserInfo: [AnyHashable: Any]? = nil
    var initialScreen: OctopusInitialScreen = .mainFeed
    var titleCentered = false
    // Default to `.navigationStack` — every Flutter host is by definition a
    // UIKit-hosted controller, and the iOS SDK's `.automatic` currently maps
    // to the legacy `NavigationView` which silently drops sub-navigation
    // pushes (a post tap not opening detail, a "Yes" confirmation that leaves
    // a sub-screen in place, …) under host reparenting. The Dart wrapper's
    // default also flips to `.navigationStack`; a host that genuinely wants
    // the native iOS default can still opt in via `OctopusNavigationMode.automatic`
    // on the Dart side, which arrives here on the wire.
    var navigationMode: OctopusNavigationMode = .navigationStack
    var navBarLeadingAction: OctopusNavBarLeadingAction? = nil
    var hasCustomLogo = false
    // Preserve the pre-existing default (10 pt) when the host doesn't pass
    // an explicit bottomSafeAreaInset, so existing layouts don't shift.
    var bottomSafeAreaInset: CGFloat = 10

    if let dict = args as? [String: Any] {
      let main = (dict["primaryMain"] as? NSNumber).map { OctopusSDKFlutterPlugin.uiColorFromARGBInt($0.intValue) }
      let low = (dict["primaryLowContrast"] as? NSNumber).map { OctopusSDKFlutterPlugin.uiColorFromARGBInt($0.intValue) }
      let high = (dict["primaryHighContrast"] as? NSNumber).map { OctopusSDKFlutterPlugin.uiColorFromARGBInt($0.intValue) }
      let onPrimary = (dict["onPrimary"] as? NSNumber).map { OctopusSDKFlutterPlugin.uiColorFromARGBInt($0.intValue) }
      let logoBase64 = dict["logoBase64"] as? String
      // Only treat the logo as "custom" when the base64 actually decodes to a
      // UIImage — mirrors the decode guard in OctopusSDKFlutterPlugin.buildTheme.
      // A non-decodable / empty string must fall back to the text title below
      // rather than force an empty `.logo` placement.
      if let logoBase64, let data = Data(base64Encoded: logoBase64), UIImage(data: data) != nil {
        hasCustomLogo = true
      }
      navBarTitle = dict["navBarTitle"] as? String
      navBarPrimaryColor = (dict["navBarPrimaryColor"] as? Bool) ?? false
      // `titleCentered` maps to the native `OctopusMainFeedTitle.Placement`:
      // `true` → `.center`, `false` → `.leading` (the SDK default). Mirrors the
      // Android `OctopusHomeScreen(titleCentered:)` param, so the Flutter API
      // is symmetric across platforms.
      titleCentered = (dict["titleCentered"] as? Bool) ?? false
      // `navigationMode` (iOS SDK 1.12.2+). Mirrors the Dart
      // `OctopusNavigationMode` enum (wire value == enum `.name`). The Dart
      // wrapper always emits the chosen value now (the Flutter default is
      // `.navigationStack`, which differs from the native iOS `.automatic`
      // default — see the field declaration above). Honour both modes
      // explicitly so a host can opt back into `.automatic` if needed.
      switch dict["navigationMode"] as? String {
      case "navigationStack": navigationMode = .navigationStack
      case "automatic":       navigationMode = .automatic
      default:                break
      }
      // `navBarLeadingAction` (iOS SDK 1.12.2+). The native SDK renders a
      // close/back button on its root screen and runs the supplied closure on
      // tap (it does NOT dismiss any SwiftUI presentation — the Flutter host
      // owns dismissal). We route the tap back to Dart as `backRequested`, the
      // same event the Android back arrow emits, which `OctopusHomeScreen` maps
      // to its `onBack` callback. Emitted only when the host set a value.
      let leadingActionOnTap: () -> Void = {
        OctopusEventEmitter.shared?.sendEvent("backRequested")
      }
      switch dict["navBarLeadingAction"] as? String {
      case "close": navBarLeadingAction = .close(onTap: leadingActionOnTap)
      case "back":  navBarLeadingAction = .back(onTap: leadingActionOnTap)
      default:      break
      }
      // Backfill from Android-shape `showBackButton`. The native iOS SDK only
      // renders a leading action when the host passes a non-nil
      // `OctopusNavBarLeadingAction`. Android consumes `showBackButton`
      // directly, so a host that follows the cross-platform pattern
      // (`showBackButton: true`, no explicit `navBarLeadingAction`) gets a
      // back chevron on Android but nothing on iOS — visually identical to a
      // missing back affordance, even though `MaterialPageRoute`'s
      // swipe-from-left-edge still works underneath. Map the same intent to
      // `.back` on iOS so the chevron shows. Explicit `navBarLeadingAction`
      // wins (close vs back is intentional from the host).
      if navBarLeadingAction == nil, (dict["showBackButton"] as? Bool) == true {
        navBarLeadingAction = .back(onTap: leadingActionOnTap)
      }
      if let inset = dict["bottomSafeAreaInset"] as? NSNumber {
        bottomSafeAreaInset = CGFloat(inset.doubleValue)
      }
      // `showNavBar: false` selects the no-chrome variant on Android
      // (`OctopusHomeContent`). The iOS pod 1.12.0 does not expose a
      // no-navbar variant yet (tracked in
      // octopus-sdk-ios#275) — keep rendering
      // `OctopusHomeScreen` with its top bar. Hosts on iOS see the
      // SDK's title until the iOS pod ships its `OctopusHomeContent`.
      // The notice is emitted per PlatformView mount so tab-switches
      // log multiple times; that's intentional during the iOS gap so
      // it stays visible to integrators in the device console.
      if let show = dict["showNavBar"] as? Bool, !show {
        NSLog(
          "[OctopusSdkFlutter] showNavBar: false is not yet supported on iOS — "
          + "the native top bar will still render. Tracking: "
          + "octopus-sdk-ios#275."
        )
      }

      // Font sizes
      let fontSizeTitle1 = (dict["fontSizeTitle1"] as? NSNumber)?.intValue ?? 26
      let fontSizeTitle2 = (dict["fontSizeTitle2"] as? NSNumber)?.intValue ?? 20
      let fontSizeBody1 = (dict["fontSizeBody1"] as? NSNumber)?.intValue ?? 17
      let fontSizeBody2 = (dict["fontSizeBody2"] as? NSNumber)?.intValue ?? 14
      let fontSizeCaption1 = (dict["fontSizeCaption1"] as? NSNumber)?.intValue ?? 12
      let fontSizeCaption2 = (dict["fontSizeCaption2"] as? NSNumber)?.intValue ?? 10

      themeMode = dict["themeMode"] as? String
      interceptUrls = (dict["interceptUrls"] as? Bool) ?? false

      // Push-notification deep navigation (iOS 1.11+).
      //
      // Dart serializes the OctopusNotification.rawPayload (a flat
      // Map<String, String> matching the Android FCM RemoteMessage.data
      // shape) via StandardMessageCodec, which arrives here as [String: Any].
      //
      // The native SDK's NotificationsRepository reads
      // `userInfo["data"][is_octopus_notification]` and
      // `userInfo["data"][link_path]` — i.e. it expects the Octopus keys
      // under a "data" envelope (mirroring how raw APNs payloads from the
      // Octopus backend are shaped). Re-wrap the flat map under "data"
      // before handing it to OctopusHomeScreen.
      if let raw = dict["notificationUserInfo"] as? [String: Any], !raw.isEmpty {
        // If the caller already provided a `data` envelope (e.g. they passed
        // the full APNs userInfo through unchanged), honor it; otherwise wrap.
        if raw["data"] is [String: Any] {
          var converted: [AnyHashable: Any] = [:]
          for (k, v) in raw { converted[k as AnyHashable] = v }
          notificationUserInfo = converted
        } else {
          notificationUserInfo = ["data": raw]
        }
      }

      // Precedence rule: a non-empty notification deep-link (`linkPath`)
      // wins over `initialScreen`. iOS's `displayScreenAfterNotificationTapped`
      // already overrides the start destination when `notificationUserInfo`
      // is set, so we just pass `.mainFeed` in that case to avoid
      // mounting an initial screen the notification handler would then
      // overwrite.
      let linkPath = dict["linkPath"] as? String
      if linkPath == nil || linkPath!.isEmpty {
        initialScreen = decodeInitialScreen(dict["initialScreen"])
      } else {
        initialScreen = .mainFeed
      }

      if main != nil || low != nil || high != nil || onPrimary != nil || logoBase64 != nil ||
         fontSizeTitle1 != 26 || fontSizeTitle2 != 20 || fontSizeBody1 != 17 ||
         fontSizeBody2 != 14 || fontSizeCaption1 != 12 || fontSizeCaption2 != 10 ||
         themeMode != nil {
        theme = OctopusSDKFlutterPlugin.buildTheme(
          main: main ?? .systemBlue,
          low: low ?? UIColor.systemBlue.withAlphaComponent(0.2),
          high: high ?? .white,
          onPrimary: onPrimary ?? .white,
          logoBase64: logoBase64,
          fontSizeTitle1: fontSizeTitle1,
          fontSizeTitle2: fontSizeTitle2,
          fontSizeBody1: fontSizeBody1,
          fontSizeBody2: fontSizeBody2,
          fontSizeCaption1: fontSizeCaption1,
          fontSizeCaption2: fontSizeCaption2,
          themeMode: themeMode
        )
      }
    }

    // Set URL interception callback on the SDK instance
    if interceptUrls {
      octopus.set(onNavigateToURLCallback: { url in
        print("iOS: onNavigateToURLCallback called - sending event for: \(url.absoluteString)")
        OctopusEventEmitter.shared?.sendEvent("navigateToUrl", data: ["url": url.absoluteString])
        return .handledByApp
      })
    } else {
      octopus.set(onNavigateToURLCallback: nil)
    }

    // Build the canonical OctopusMainFeedTitle. A configured theme logo takes
    // **precedence over a text title** — otherwise the custom theme's logo
    // would never show whenever a `navBarTitle` is also set (e.g. the sample's
    // Community tab), since `.text` would always win. Falls back to the text
    // title, then to the default logo. Placement follows `titleCentered`
    // (.center/.leading).
    let titlePlacement: OctopusMainFeedTitle.Placement =
      titleCentered ? .center : .leading
    let mainFeedTitle: OctopusMainFeedTitle = {
      if hasCustomLogo {
        return OctopusMainFeedTitle(content: .logo, placement: titlePlacement)
      }
      if let title = navBarTitle {
        return OctopusMainFeedTitle(
          content: .text(.init(text: title)),
          placement: titlePlacement
        )
      }
      return OctopusMainFeedTitle(content: .logo, placement: titlePlacement)
    }()

    let root: AnyView
    if let theme {
      root = AnyView(OctopusHomeScreenWithCallback(
        octopus: octopus,
        mainFeedNavBarTitle: mainFeedTitle,
        mainFeedColoredNavBar: navBarPrimaryColor,
        initialScreen: initialScreen,
        navigationMode: navigationMode,
        navBarLeadingAction: navBarLeadingAction,
        notificationUserInfo: notificationUserInfo,
        onNavigateToLogin: triggerOnNavigateToLoginCallback,
        bottomSafeAreaInset: bottomSafeAreaInset
      ).environment(\.octopusTheme, theme)
      .preferredColorScheme(themeMode == "dark" ? .dark : themeMode == "light" ? .light : nil))
    } else {
      root = AnyView(OctopusHomeScreenWithCallback(
        octopus: octopus,
        mainFeedNavBarTitle: mainFeedTitle,
        mainFeedColoredNavBar: navBarPrimaryColor,
        initialScreen: initialScreen,
        navigationMode: navigationMode,
        navBarLeadingAction: navBarLeadingAction,
        notificationUserInfo: notificationUserInfo,
        onNavigateToLogin: triggerOnNavigateToLoginCallback,
        bottomSafeAreaInset: bottomSafeAreaInset
      ).preferredColorScheme(themeMode == "dark" ? .dark : themeMode == "light" ? .light : nil))
    }
    let controller = UIHostingController(rootView: root)
    let parentViewController = self.findViewController()
    parentViewController?.addChild(controller)
    controller.view.backgroundColor = .clear

    // Force the interface style based on themeMode
    if let themeMode = themeMode {
      switch themeMode {
      case "light": window?.overrideUserInterfaceStyle = .light
      case "dark":  window?.overrideUserInterfaceStyle = .dark
      default:      window?.overrideUserInterfaceStyle = .unspecified
      }
    }

    addSubview(controller.view)
    controller.view.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        controller.view.topAnchor.constraint(equalTo: topAnchor),
        controller.view.bottomAnchor.constraint(equalTo: bottomAnchor),
        controller.view.leadingAnchor.constraint(equalTo: leadingAnchor),
        controller.view.trailingAnchor.constraint(equalTo: trailingAnchor)
      ])

    controller.didMove(toParent: parentViewController)

    hostingController = controller
  }

  private func addErrorLabel() {
    let label = UILabel(frame: bounds)
    label.text = "SDK not initialized.\nCall initialize() first."
    label.textAlignment = .center
    label.numberOfLines = 0
    label.textColor = .systemGray
    label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    addSubview(label)
  }

  private func triggerOnNavigateToLoginCallback() {
    print("iOS: triggerOnNavigateToLoginCallback called")
    OctopusEventEmitter.shared?.emitNavigateToLogin()
  }
}

// Helper extension to find the parent UIViewController
extension UIView {
  func findViewController() -> UIViewController? {
    if let nextResponder = self.next as? UIViewController {
      return nextResponder
    } else if let nextResponder = self.next as? UIView {
      return nextResponder.findViewController()
    } else {
      return nil
    }
  }
}
