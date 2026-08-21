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
  /// Extra bottom inset (points) to reserve *beyond* the system safe area this
  /// view already sits in — the additive contract of the native
  /// `OctopusHomeScreen(bottomSafeAreaInset:)`.
  ///
  /// This is NOT the value the Dart host passed: the Dart-facing
  /// `bottomSafeAreaInset` is a *total* bottom padding (the Android bridge
  /// consumes the system insets, so there the whole value applies). The
  /// container normalizes it — see `SafeHostingContainerView.normalizedBottomInset`
  /// — before handing it here, so the same Dart value renders identically on
  /// both platforms.
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

/// Wraps `OctopusProfileScreen` — the native view backing the Dart
/// `OctopusInitialScreen.profile` / `OctopusProfileScreen` entry point — with the
/// same login-notification observer `OctopusHomeScreenWithCallback` installs, so
/// a "log in" tap inside the profile screen reaches the Dart host.
///
/// It takes no `bottomSafeAreaInset`: the native view has no such parameter (it
/// pins its own to 0 internally), so there is nothing to normalize or track
/// here — which is why this wrapper sits outside `NormalizedBottomInsetHost`
/// rather than inside it.
struct OctopusProfileScreenWithCallback: View {
  let octopus: OctopusSDK
  /// The host app's own id for the member whose profile to show, or `nil` for the
  /// connected user's own (editable) profile.
  let clientUserId: String?
  /// Same container choice as the home screen — see `OctopusHomeScreenWithCallback`.
  let navigationMode: OctopusNavigationMode
  let navBarLeadingAction: OctopusNavBarLeadingAction?
  let onNavigateToLogin: () -> Void

  var body: some View {
    OctopusProfileScreen(
      octopus: octopus,
      clientUserId: clientUserId,
      navigationMode: navigationMode,
      navBarLeadingAction: navBarLeadingAction
    )
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OctopusNavigateToLogin"))) { _ in
      onNavigateToLogin()
    }
  }
}

/// Observable box holding the normalized bottom inset handed to the embedded
/// SwiftUI tree.
///
/// The value changes after mount (first layout resolves the container's safe
/// area, rotation and iPad multitasking change it later), and it must reach
/// SwiftUI *without* rebuilding the `UIHostingController` — replacing its
/// `rootView` would drop the identity of the `AnyView` it wraps and reset the
/// SDK's `@StateObject` managers mid-session.
private final class BottomInsetStore: ObservableObject {
  @Published var value: CGFloat = 0
}

/// Thin `@ObservedObject` shell that re-renders its content when the normalized
/// bottom inset changes.
///
/// Keeping the observation here (rather than inside `OctopusHomeScreenWithCallback`)
/// means the embedded SDK view keeps its position in the view tree, so its own
/// `@StateObject` managers survive an inset update: only its
/// `bottomSafeAreaInset` parameter changes.
///
/// The screens rendered *below* it are only safe because the emitted value never
/// reaches 0: the native `insetableMainNavigationView` gates on
/// `bottomSafeAreaInset > 0`, and crossing that boundary would swap a
/// `_ConditionalContent` branch and discard the displayed screen's state. See
/// `SafeHostingContainerView.gatePinningInset` — that floor is what allows the
/// value to be tracked live rather than frozen.
private struct NormalizedBottomInsetHost<Content: View>: View {
  @ObservedObject var store: BottomInsetStore
  let content: (CGFloat) -> Content

  var body: some View { content(store.value) }
}

/// Which native view the bridge mounts for a decoded Dart `initialScreen`.
///
/// Every case but one is an `OctopusInitialScreen` handed to `OctopusHomeScreen`.
/// The Dart `OctopusInitialScreen.profile` case has **no counterpart in the
/// native iOS enum** — iOS ships a separate top-level `OctopusProfileScreen`
/// view for it (Android pushes a `ProfileSummary` destination inside the same
/// `NavHost` as the other bridge-mode entries). So the decode result has to be
/// able to say "mount a different view", not just "which start screen".
enum BridgeInitialScreen {
  /// Mount `OctopusHomeScreen` with this start screen.
  case home(OctopusInitialScreen)
  /// Mount `OctopusProfileScreen` for this member, or — `nil` — for the
  /// connected user's own profile.
  case profile(clientUserId: String?)
}

/// How a member-scoped entry point identifies its member, decoded from the wire.
///
/// A bridge-level mirror of the native `ActivityScreenInfo.Source`, which is
/// `package`-visible in the iOS SDK and therefore unreadable from here: the two
/// public `ActivityScreenInfo` initializers accept a source but nothing reads one
/// back out, and the `profile` case needs the same discriminator without going
/// through `ActivityScreenInfo` at all.
private enum BridgeMemberId {
  case clientUserId(String)
  case profileId(String)
}

/// Decodes the shared `{source, id}` member payload every member-scoped entry
/// point carries.
///
/// The one iOS counterpart of the Dart `memberIdToMap` encoder
/// (`lib/src/member_id.dart`) and the Android `MemberId.fromMap`. Returns `nil`
/// for a non-map, an unknown `source`, or a missing / blank `id`; each caller
/// decides what that means for it.
///
/// A pure decoder: the id is forwarded exactly as it arrived. Normalization
/// (trimming, and treating a blank id as no member) belongs to `memberIdToMap`,
/// the single producer of this payload — so both bridges stay byte-for-byte
/// agreed on what they hand their native SDK.
private func decodeMemberId(_ raw: Any?) -> BridgeMemberId? {
  guard let map = raw as? [String: Any],
        let id = (map["id"] as? String)?.nilIfBlank else { return nil }
  switch map["source"] as? String {
  case "clientUserId": return .clientUserId(id)
  case "profileId":    return .profileId(id)
  default:
    NSLog("[OctopusSdkFlutter] member: unknown source=\(map["source"] ?? "nil") — ignoring the member")
    return nil
  }
}

/// Decodes the Dart `OctopusInitialScreen.toMap()` wire shape into the native
/// view the bridge should mount.
///
/// Unknown / malformed values fold to `.mainFeed`. Image bytes from the
/// `createPost` variant are intentionally dropped here: the embedded
/// initialScreen entry point is not the route hosts use to share an image
/// (`showOctopusCreatePostScreen` is). Hosts can still pass text, topicId,
/// and CTA through.
private func decodeInitialScreen(_ raw: Any?) -> BridgeInitialScreen {
  guard let map = raw as? [String: Any] else { return .home(.mainFeed) }
  switch map["type"] as? String {
  case "mainFeed", nil:
    return .home(.mainFeed)
  case "post":
    guard let postId = map["postId"] as? String,
          !postId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      NSLog("[OctopusSdkFlutter] initialScreen.post: missing/blank postId — falling back to mainFeed")
      return .home(.mainFeed)
    }
    return .home(.post(.init(postId: postId)))
  case "group":
    guard let groupId = map["groupId"] as? String,
          !groupId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      NSLog("[OctopusSdkFlutter] initialScreen.group: missing/blank groupId — falling back to mainFeed")
      return .home(.mainFeed)
    }
    return .home(.group(.init(groupId: groupId)))
  case "activity":
    // Unlike `profile`, this screen has no "connected user" meaning to fall back
    // on — Dart always sends a member here, so an absent one is malformed.
    guard let member = decodeMemberId(map["member"]) else {
      NSLog("[OctopusSdkFlutter] initialScreen.activity: missing member — falling back to mainFeed")
      return .home(.mainFeed)
    }
    switch member {
    case let .clientUserId(id): return .home(.activity(.init(clientUserId: id)))
    case let .profileId(id):    return .home(.activity(.init(profileId: id)))
    }
  case "profile":
    // An absent (or undecodable) member means the connected user's own profile —
    // `OctopusProfileScreen(clientUserId: nil)`.
    switch decodeMemberId(map["member"]) {
    case nil:
      return .profile(clientUserId: nil)
    case let .clientUserId(id):
      return .profile(clientUserId: id)
    case let .profileId(id):
      // Not reachable from the current Dart API — `OctopusInitialScreen.profile`
      // takes only a clientUserId, precisely because iOS's `OctopusProfileScreen`
      // has no by-Octopus-id form (Android's `ProfileSummary` does, and the
      // shared member payload carries it for that reason). Handled rather than
      // ignored so the requested member is never swapped for the connected user:
      // the activity screen is the one native view that opens an Octopus id
      // directly, and it is what the Dart docs point hosts to for this case.
      //
      // The Android bridge does NOT mirror this fallback — its `ProfileSummary`
      // takes an Octopus id, so it opens that member's profile proper. Each side
      // opens the closest thing its native SDK has, which is only tenable while
      // no Dart API can reach this branch. Whoever adds
      // `OctopusInitialScreen.profile(profileId:)` has to settle the two on one
      // behaviour; the same warning sits on `InitialScreenSpec.Profile` in
      // `InitialScreenSpec.kt`.
      NSLog(
        "[OctopusSdkFlutter] initialScreen.profile by Octopus profile id is not supported on iOS — "
        + "opening that member's activity screen instead"
      )
      return .home(.activity(.init(profileId: id)))
    }
  case "createPost":
    let prefilled = map["prefilledPost"] as? [String: Any]
    guard let prefilled = prefilled else {
      return .home(.createPost(.init(prefilledPost: nil)))
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
    return .home(.createPost(.init(prefilledPost: payload)))
  default:
    NSLog("[OctopusSdkFlutter] initialScreen: unknown type=\(map["type"] ?? "nil") — falling back to mainFeed")
    return .home(.mainFeed)
  }
}

private extension String {
  var nilIfEmpty: String? { isEmpty ? nil : self }

  /// `nil` when there is nothing but whitespace here, otherwise the string
  /// **unchanged** — the same "missing/blank" test the `post` / `group` ids get
  /// above, and the same one Android's `MemberId.fromMap` applies.
  ///
  /// It deliberately does not return the trimmed value: an earlier version did,
  /// which made a padded id (`" cu-1 "`) resolve on iOS and miss on Android for
  /// the same call. The producer trims now; a decoder that also normalized would
  /// hide the next such divergence instead of ruling it out.
  var nilIfBlank: String? {
    trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
  }
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

  /// Total bottom padding (points) the Dart host **explicitly** asked for.
  ///
  /// `nil` when the host passed no value: the historical additive default then
  /// applies untouched and no normalization happens at all, so hosts that never
  /// used the parameter keep byte-identical layout.
  private var requestedBottomSafeAreaInset: CGFloat?

  /// Floor applied to every host-provided inset so the value stays strictly
  /// positive for the view's whole lifetime.
  ///
  /// The native SDK gates its inset on a `@ViewBuilder` condition
  /// (`insetableMainNavigationView`: `if bottomSafeAreaInset > 0`). Crossing that
  /// boundary swaps a `_ConditionalContent` case, and SwiftUI treats the result as
  /// a different child: it discards the `@State` beneath it, which here is the
  /// displayed screen — feed scroll position, and the text and image already
  /// entered in the create-post editor.
  ///
  /// Normalization legitimately reaches exactly 0 whenever the system inset
  /// already covers what the host asked for, which is the common case. Pinning
  /// the gate on instead of freezing the value is what makes live tracking safe,
  /// and live tracking is necessary: the container's own geometry can lag the
  /// window's. Measured on iPhone 16 / iOS 18.6, the first frame of a
  /// landscape→portrait restore still reports the stale landscape bounds and a
  /// bottom safe area of 0 while the window already reports 34 pt. A value
  /// frozen by any "the layout looks settled now" test could be frozen exactly
  /// there — permanently — and no size-based test tells that frame apart from a
  /// settled one.
  ///
  /// 0.01 pt renders nothing.
  ///
  /// **Known divergence.** Normalization does move the native keyboard
  /// threshold. The native SDK compares `keyboardHeight` against the same
  /// `bottomSafeAreaInset` it uses as a height, so changing the value from `R`
  /// to `R - S` changes that comparison too. The outcome differs for any reported
  /// `keyboardHeight` in `(R - S, R]`, and is identical everywhere else — so a
  /// full-height software keyboard is never affected (it dwarfs both values). The
  /// reachable case is a **hardware keyboard** (iPad or a Bluetooth keyboard on
  /// iPhone), which reports only the accessory bar rather than a full keyboard:
  /// with `R = 70` and `S = 20`, a reported 55 pt means `55 <= 70` used to keep
  /// the band while `55 <= 50` now drops it, so host bottom chrome can overlap
  /// the composer while typing.
  ///
  /// This cannot be fixed from the bridge: one scalar drives both the reserved
  /// height and the threshold, and no single value satisfies both meanings.
  /// Resolving it properly needs the native SDK to take the total and the
  /// threshold separately — out of scope here, since the native additive
  /// contract is public API owned upstream.
  private static let gatePinningInset: CGFloat = 0.01

  private let bottomInsetStore = BottomInsetStore()

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

  /// The container's safe area is not resolved when `didMoveToWindow()` fires, and
  /// it keeps changing afterwards — presentation animations move the view, and so
  /// do rotation, iPad multitasking and a host that re-lays the platform view out.
  /// Re-normalize on both signals; `gatePinningInset` is what keeps that safe.
  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    updateNormalizedBottomInset()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    updateNormalizedBottomInset()
  }

  /// Converts the Dart-facing *total* bottom padding into the *additive* inset
  /// the native SDK expects.
  ///
  /// `OctopusHomeScreen(bottomSafeAreaInset:)` applies its value through
  /// SwiftUI's `.safeAreaInset(edge: .bottom)`, which stacks **on top of** the
  /// safe area the view already has. The Android bridge instead consumes the
  /// system insets before mounting (`consumeWindowInsets(WindowInsets.systemBars)`),
  /// so there the host's value is the only bottom padding.
  ///
  /// Subtracting the safe area this container actually sits in makes the two
  /// bridges agree: `bottomSafeAreaInset: 56` reserves 56 pt of bottom padding
  /// on both platforms. When the system already reserves at least as much as the
  /// host asked for, the result is `0` and no extra inset is added — the system
  /// inset alone already satisfies the request.
  ///
  /// `systemInset` is the safe area of the view the SDK is embedded in — the
  /// *container's*, not the window's: a host that already lays the platform view
  /// out above the home indicator has `0` here and correctly receives the full
  /// requested value.
  private func normalizedBottomInset(for requested: CGFloat, systemInset: CGFloat) -> CGFloat {
    max(0, requested - systemInset)
  }

  /// Recomputes the inset from the container's current geometry.
  ///
  /// Idempotent, and no-op for hosts that sent no explicit value. There is no
  /// feedback path back into `safeAreaInsets`: the hosting controller's view is a
  /// child pinned to this container's edges, and `.safeAreaInset(edge: .bottom)`
  /// only affects the safe area *inside* the SwiftUI subtree, so writing the
  /// store cannot change the input that produced it.
  private func updateNormalizedBottomInset() {
    guard let requested = requestedBottomSafeAreaInset else { return }
    let normalized = max(
      normalizedBottomInset(for: requested, systemInset: safeAreaInsets.bottom),
      Self.gatePinningInset
    )
    guard bottomInsetStore.value != normalized else { return }
    bottomInsetStore.value = normalized
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
    var interceptProfileTaps = false
    var hasModifyUserHandler = false
    var notificationUserInfo: [AnyHashable: Any]? = nil
    var initialScreen: BridgeInitialScreen = .home(.mainFeed)
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
    // The host's explicit bottomSafeAreaInset, when it sent one. Absent → the
    // historical additive default (10 pt on top of whatever safe area the view
    // sits in) is kept verbatim and no normalization is applied, so hosts that
    // never used the parameter see no layout change at all.
    //
    // Note that Dart omits the key entirely when the value is 0 (see
    // `OctopusSDK.embeddedView`), so "explicitly 0" never reaches here — on the
    // wire it is indistinguishable from "not provided".
    var explicitBottomSafeAreaInset: CGFloat?

    if let dict = args as? [String: Any] {
      let main = (dict["primaryMain"] as? NSNumber).map { OctopusSDKFlutterPlugin.uiColorFromARGBInt($0.intValue) }
      let low = (dict["primaryLowContrast"] as? NSNumber).map { OctopusSDKFlutterPlugin.uiColorFromARGBInt($0.intValue) }
      let high = (dict["primaryHighContrast"] as? NSNumber).map { OctopusSDKFlutterPlugin.uiColorFromARGBInt($0.intValue) }
      let onPrimary = (dict["onPrimary"] as? NSNumber).map { OctopusSDKFlutterPlugin.uiColorFromARGBInt($0.intValue) }
      let background = (dict["background"] as? NSNumber).map { OctopusSDKFlutterPlugin.uiColorFromARGBInt($0.intValue) }
      let link = (dict["link"] as? NSNumber).map { OctopusSDKFlutterPlugin.uiColorFromARGBInt($0.intValue) }
      let fontFamily = dict["fontFamily"] as? String
      let fontWeight = (dict["fontWeight"] as? NSNumber)?.intValue
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
        explicitBottomSafeAreaInset = CGFloat(inset.doubleValue)
      }
      // `showNavBar: false` selects the no-chrome variant on Android
      // (`OctopusHomeContent`). The iOS pod 1.12.0 does not expose a
      // no-navbar variant yet (tracked in
      // internal tracking) — keep rendering
      // `OctopusHomeScreen` with its top bar. Hosts on iOS see the
      // SDK's title until the iOS pod ships its `OctopusHomeContent`.
      // The notice is emitted per PlatformView mount so tab-switches
      // log multiple times; that's intentional during the iOS gap so
      // it stays visible to integrators in the device console.
      if let show = dict["showNavBar"] as? Bool, !show {
        NSLog(
          "[OctopusSdkFlutter] showNavBar: false is not yet supported on iOS — "
          + "the native top bar will still render. Tracking: "
          + "internal tracking."
        )
      }

      // Font sizes. All seven stay optional all the way to `buildTheme`: Dart
      // omits the key entirely for an unset slot, and `nil` is how that slot asks
      // for the SDK's own `UIFontMetrics`-scaled default. Substituting a number
      // here would pin the type size against Dynamic Type for every host that
      // sets any *other* theme key.
      let fontSizeTitle1 = (dict["fontSizeTitle1"] as? NSNumber)?.intValue
      let fontSizeTitle2 = (dict["fontSizeTitle2"] as? NSNumber)?.intValue
      let fontSizeBody1 = (dict["fontSizeBody1"] as? NSNumber)?.intValue
      let fontSizeBody2 = (dict["fontSizeBody2"] as? NSNumber)?.intValue
      let fontSizeCaption1 = (dict["fontSizeCaption1"] as? NSNumber)?.intValue
      let fontSizeCaption2 = (dict["fontSizeCaption2"] as? NSNumber)?.intValue
      let fontSizeNavBarItem = (dict["fontSizeNavBarItem"] as? NSNumber)?.intValue

      themeMode = dict["themeMode"] as? String
      interceptUrls = (dict["interceptUrls"] as? Bool) ?? false
      interceptProfileTaps = (dict["interceptProfileTaps"] as? Bool) ?? false
      hasModifyUserHandler = (dict["hasModifyUserHandler"] as? Bool) ?? false

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
        initialScreen = .home(.mainFeed)
      }

      // Any theme key present at all means the host asked for a theme — every slot
      // is optional, so this is a plain presence test. It used to compare the font
      // sizes against the wrapper's own numbers, which made "unset" and
      // "explicitly set to the wrapper default" indistinguishable; now an absent
      // key is absent all the way down.
      if main != nil || low != nil || high != nil || onPrimary != nil || logoBase64 != nil ||
         background != nil || link != nil || fontFamily != nil || fontWeight != nil ||
         fontSizeNavBarItem != nil ||
         fontSizeTitle1 != nil || fontSizeTitle2 != nil || fontSizeBody1 != nil ||
         fontSizeBody2 != nil || fontSizeCaption1 != nil || fontSizeCaption2 != nil ||
         themeMode != nil {
        // Pass the optionals straight through: `buildTheme` resolves each unset
        // slot to the SDK's own default. Substituting anything here would silently
        // override the native primary palette — or the native scaled type — for a
        // host that only asked for, say, `background`.
        theme = OctopusSDKFlutterPlugin.buildTheme(
          main: main,
          low: low,
          high: high,
          onPrimary: onPrimary,
          background: background,
          link: link,
          logoBase64: logoBase64,
          fontFamily: fontFamily,
          fontWeight: fontWeight,
          fontSizeTitle1: fontSizeTitle1,
          fontSizeTitle2: fontSizeTitle2,
          fontSizeBody1: fontSizeBody1,
          fontSizeBody2: fontSizeBody2,
          fontSizeCaption1: fontSizeCaption1,
          fontSizeCaption2: fontSizeCaption2,
          fontSizeNavBarItem: fontSizeNavBarItem,
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

    // Unified Profile activation switch. The native SDK treats a non-nil
    // callback as "the host handles every profile tap" and stops showing its own
    // profile screens, so it is set ONLY when the Dart host opted in — and
    // explicitly cleared otherwise, because this is a runtime setter on the
    // shared SDK instance: a previous mount that opted in would otherwise keep
    // suppressing the native screens for every later view.
    //
    // Android takes the equivalent as a mount-time composable parameter; the
    // Dart-facing contract is mount-time on both platforms, which is why the
    // flag rides in the view's creation params rather than a method call.
    if interceptProfileTaps {
      octopus.set(onNavigateToProfileCallback: { clientUserId in
        OctopusEventEmitter.shared?.sendEvent(
          "navigateToProfile",
          data: ["clientUserId": clientUserId]
        )
      })
      // The activity screen's "Edit my profile" item is gated on this SECOND,
      // deliberately separate callback: the native iOS SDK keeps SSO's
      // `modifyUser` (already wired, and used by its own profile screen) apart
      // from this Unified-Profile-only hook, and hides the menu item when it is
      // nil so it never dead-ends. Routed to the same `editUser` event as
      // `modifyUser`, so the host's existing `onModifyUser` handles both.
      //
      // Honour that nil-checkability instead of defeating it: wire it only when
      // the host actually has a handler, otherwise the item would render and its
      // tap would land in a null Dart callback. (Android wires its equivalent
      // unconditionally — one native parameter serves both edit paths there — so
      // an Android host without `onModifyUser` can still see a dead-end item.)
      if hasModifyUserHandler {
        octopus.set(onNavigateToProfileEditCallback: { fieldToEdit in
          OctopusEventEmitter.shared?.emitEditUser(
            fieldToEdit: OctopusSDKFlutterPlugin.profileFieldWireValue(fieldToEdit)
          )
        })
      } else {
        octopus.set(onNavigateToProfileEditCallback: nil)
      }
    } else {
      octopus.set(onNavigateToProfileCallback: nil)
      octopus.set(onNavigateToProfileEditCallback: nil)
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

    if let requested = explicitBottomSafeAreaInset {
      requestedBottomSafeAreaInset = requested
      // First estimate only. The container's own inset is often unresolved here
      // (this runs from `didMoveToWindow()`), while the window's is already
      // correct and equals the container's whenever the platform view reaches the
      // bottom of the screen — the common case, so this avoids a visible jump on
      // the first frame. `layoutSubviews` then tracks the real geometry.
      bottomInsetStore.value = max(
        normalizedBottomInset(
          for: requested,
          systemInset: window?.safeAreaInsets.bottom ?? 0
        ),
        Self.gatePinningInset
      )
    } else {
      // No explicit value → keep the historical additive default untouched.
      // `requestedBottomSafeAreaInset` stays nil, so the latch never runs and this
      // value is constant for the view's lifetime, exactly as before.
      bottomInsetStore.value = 10
    }

    // Hoisted out of the view builders below so they capture nothing: referencing
    // the method inside them would capture `self`, and those closures are retained
    // by the hosting controller that this view itself owns. The callback only
    // forwards to a singleton, so there is no instance state to reach — same
    // pattern as `leadingActionOnTap` above.
    let onNavigateToLogin: () -> Void = {
      print("iOS: triggerOnNavigateToLoginCallback called")
      OctopusEventEmitter.shared?.emitNavigateToLogin()
    }

    // Which native view to mount. `.profile` is the one Dart initial screen with
    // no native `OctopusInitialScreen` counterpart — iOS ships a separate
    // top-level view for it (see `BridgeInitialScreen`). Consequences for that
    // branch, mirrored in the Dart doc: the main-feed nav-bar title and the
    // notification deep link do not apply to it, and it has no
    // `bottomSafeAreaInset` parameter to forward.
    let content: AnyView
    switch initialScreen {
    case let .home(homeScreen):
      content = AnyView(NormalizedBottomInsetHost(store: bottomInsetStore) { inset in
        OctopusHomeScreenWithCallback(
          octopus: octopus,
          mainFeedNavBarTitle: mainFeedTitle,
          mainFeedColoredNavBar: navBarPrimaryColor,
          initialScreen: homeScreen,
          navigationMode: navigationMode,
          navBarLeadingAction: navBarLeadingAction,
          notificationUserInfo: notificationUserInfo,
          onNavigateToLogin: onNavigateToLogin,
          bottomSafeAreaInset: inset
        )
      })
    case let .profile(clientUserId):
      content = AnyView(OctopusProfileScreenWithCallback(
        octopus: octopus,
        clientUserId: clientUserId,
        navigationMode: navigationMode,
        navBarLeadingAction: navBarLeadingAction,
        onNavigateToLogin: onNavigateToLogin
      ))
    }

    let colorScheme: ColorScheme? =
      themeMode == "dark" ? .dark : themeMode == "light" ? .light : nil
    let root: AnyView
    if let theme {
      root = AnyView(content.environment(\.octopusTheme, theme)
        .preferredColorScheme(colorScheme))
    } else {
      root = AnyView(content.preferredColorScheme(colorScheme))
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
