import 'package:flutter/material.dart';
import 'dart:async';
import 'octopus_initial_screen.dart';
import 'octopus_nav_bar_leading_action.dart';
import 'octopus_navigation_mode.dart';
import 'octopus_theme.dart';
import 'octopus_sdk.dart';

/// A Flutter widget that displays the native Octopus UI embedded within your Flutter app.
///
/// This widget provides a simple way to integrate the Octopus Community UI directly
/// into your Flutter application without opening a separate modal.
///
/// Example usage:
/// ```dart
/// OctopusHomeScreen(
///   navBarTitle: 'Community',
///   theme: OctopusTheme(
///     primaryMain: Colors.blue,
///     logoBase64: myLogoBase64,
///     themeMode: OctopusThemeMode.dark,
///   ),
///   showBackButton: false,
///   onNavigateToLogin: () {
///     // Handle navigation to login screen
///     print('User navigated to login');
///   },
///   onModifyUser: (fieldToEdit) {
///     // Handle profile modification
///     if (fieldToEdit != null) {
///       print('User wants to edit: $fieldToEdit');
///     } else {
///       print('User wants to edit profile');
///     }
///   },
/// )
/// ```
class OctopusHomeScreen extends StatefulWidget {
  /// Title displayed in the navigation bar
  ///
  /// iOS: When provided, replaces the logo completely
  /// Android: Can be displayed alongside the logo
  final String? navBarTitle;

  /// If true, uses the primary color for the navigation bar background
  final bool navBarPrimaryColor;

  /// If true, shows the leading back button in the navigation bar. On Android
  /// the M3 chevron is rendered directly; on iOS the bridge backfills to
  /// `OctopusNavBarLeadingAction.back` when [navBarLeadingAction] is null. On
  /// both platforms an explicit [navBarLeadingAction] takes precedence over
  /// this flag (Android via the native `leadingNavigationIcon`, iOS via
  /// `navBarLeadingAction`). The tap is surfaced as `backRequested` → [onBack]
  /// on both platforms.
  final bool showBackButton;

  /// Whether the navigation-bar title is centered. `true` centers the title in
  /// the SDK's top app bar, `false` (default) leaves it leading-aligned.
  ///
  /// Supported on **both platforms**:
  /// - **Android** → the native `OctopusHomeScreen(titleCentered:)` composable
  ///   param.
  /// - **iOS** → maps to `OctopusMainFeedTitle.Placement` (`.center` when
  ///   `true`, `.leading` otherwise) on the main feed.
  final bool titleCentered;

  /// Custom theme for the interface (colors, font sizes, logo)
  final OctopusTheme? theme;

  /// Whether to show a loading indicator while the native view is initializing
  final bool showLoadingIndicator;

  /// Widget to display while loading (if showLoadingIndicator is true)
  final Widget? loadingWidget;

  /// Error widget to display if the native view fails to load
  final Widget? errorWidget;

  /// Whether to show error states (default: true)
  final bool showError;

  /// Whether the widget should be enabled
  final bool enabled;

  /// Callback function called when the user navigates to login
  final VoidCallback? onNavigateToLogin;

  /// Callback function called when the user wants to modify their profile
  ///
  /// The parameter is the field that has been asked to be edited by the user.
  /// Null if the user tapped on "Edit my profile".
  final Function(String?)? onModifyUser;

  /// Callback invoked when the user taps **any** profile inside the community —
  /// another member's or their own — so your app can open **its own** profile
  /// screen for that member ("Unified Profile").
  ///
  /// The parameter is the tapped member's `clientUserId`: your app's own id for
  /// them, never null. Pair it with [OctopusSDK.fetchCommunityData] to enrich
  /// your screen with that member's Octopus stats.
  ///
  /// **Setting this callback changes navigation behaviour**: every profile tap
  /// routes to you and the SDK stops showing its native profile screens. That
  /// is why it is opt-in — leave it null (the default) to keep the SDK's own
  /// profile screens.
  ///
  /// Activation is an **AND gate**: wiring this alone is not enough, the
  /// community must also be configured to expose client user ids. Until both
  /// hold, the SDK keeps its native screens and this callback is never invoked.
  /// A member with no client user id — a guest, an Octopus-authentication
  /// member, or a back-office-created profile — opens the Octopus activity
  /// screen instead, so you never receive a tap you cannot resolve.
  ///
  /// Whether it is set at all is decided **when the view mounts**: Android takes
  /// the callback as a mount-time parameter of the native composable, so
  /// *toggling* it on or off has no effect until the view is rebuilt from
  /// scratch. Swapping one non-null closure for another does apply immediately —
  /// dispatch reads the current widget's callback on each tap.
  ///
  /// **One embedded view at a time.** On iOS the native switch is a setter on
  /// the shared SDK instance, so it is last-mount-wins: if a second embedded
  /// view mounts over one that opted in (a pushed route, a modal) and did not
  /// itself opt in, it turns interception off for both, and vice versa. Keep a
  /// single embedded view alive, or opt every one of them in the same way.
  /// Android is per-view and unaffected.
  final void Function(String clientUserId)? onNavigateToProfile;

  /// Callback invoked when the user taps the back button.
  /// Used by [OctopusSDK.showOctopusHomeScreen] to pop the modal route.
  final VoidCallback? onBack;

  /// Callback function called when a URL is tapped inside the Octopus Community UI.
  ///
  /// When set, URLs are intercepted and forwarded to Flutter instead of being
  /// opened by the SDK. Return [UrlOpeningStrategy.handledByApp] if your app
  /// handles the URL, or [UrlOpeningStrategy.handledByOctopus] to let the SDK
  /// open it in the default browser.
  ///
  /// When not set, all URLs are handled by the SDK (default behavior).
  final UrlOpeningStrategy Function(String)? onNavigateToUrl;

  /// Push notification whose deep-link target the native view should open.
  ///
  /// When set, the native view opens pre-navigated to the content referenced
  /// by the notification. Typically provided via [OctopusSDK.openNotification].
  final OctopusNotification? notification;

  /// Total bottom padding (logical pixels) the native screen reserves at the
  /// bottom so its floating "Write a post" pill sits above the host app's own
  /// bottom chrome (e.g. a Flutter `BottomNavigationBar`). Pass the host
  /// bottom-nav height + safe-area bottom.
  ///
  /// Defaults to `0`, which on **Android** means **"resolve it from where this
  /// widget is mounted"** — not "reserve nothing". The SDK reserves whatever
  /// bottom padding the ambient `MediaQuery` still has left: mounted full-screen
  /// on an edge-to-edge device (API 35+) that resolves to the system
  /// navigation-bar inset, so the pill stays clear of it with no host
  /// configuration; mounted under a `SafeArea` or above a bottom nav that already
  /// consumed the padding, it resolves to `0` and the native default applies
  /// instead. Under `Scaffold(extendBody: true)` it resolves the bottom bar's
  /// height, since `Scaffold` re-injects that height into the body's `padding` —
  /// which is the case this parameter was designed for: the view runs behind the
  /// bar there.
  ///
  /// **iOS does not resolve, and its default is unchanged.** The embedded view
  /// already sits inside the safe area there, so nothing is occluded — and since
  /// the iOS bridge reads this value as a total *minus* that safe area, inferring
  /// one would replace its additive 10 pt with ~0 and lose height for nothing. An
  /// explicit value above `0` still applies on both platforms, identically.
  ///
  /// To reserve **nothing at all**, wrap the widget in an ancestor that consumes
  /// the bottom padding:
  ///
  /// ```dart
  /// MediaQuery.removePadding(
  ///   context: context,
  ///   removeBottom: true,
  ///   child: OctopusHomeScreen(...),
  /// )
  /// ```
  ///
  /// An explicit `0` cannot express it, since `0` *is* the "resolve it for me"
  /// default — and neither can a negative value: anything at or below `0`
  /// resolves.
  ///
  /// On Android, padding the layout is **not** the same as consuming the padding:
  /// a plain `Padding`, a `Column` above a fixed footer or a `Stack` bottom
  /// overlay leaves the ambient `MediaQuery` untouched, so the widget still
  /// resolves the full inset and reserves it a second time inside the native
  /// view. Those shapes should either pass the total they want or consume the
  /// padding as shown above.
  ///
  /// One more Android case needs an explicit value: a widget first built while a
  /// keyboard is up resolves `0` and keeps it for its whole life, because the
  /// engine folds the bottom inset into `viewInsets` and the native view reads the
  /// value once, at creation. A `Scaffold` body does not escape this. Pass the
  /// inset yourself if your host can mount the SDK with the keyboard already open.
  ///
  /// This is a *total* padding, not an addition on top of the system safe area:
  /// the Android bridge consumes the system-bar insets before mounting the native
  /// view, and the iOS bridge subtracts the safe area the embedded view sits in
  /// before handing the value to the native SDK. So the same value reserves the
  /// same band on both platforms — as long as it is at least as large as the
  /// system inset.
  ///
  /// **Platform notes.**
  /// - Below the system inset the two platforms diverge: iOS never reserves less
  ///   than the safe area it already sits in (the reserved band is effectively
  ///   `max(value, systemInset)`), while Android reserves exactly `value`.
  /// - When the **resolved** value is `0` the parameter is left off the wire and
  ///   each platform applies its own native default: Android falls back to the
  ///   SDK's default content padding; iOS keeps a 10pt inset on top of the
  ///   system safe area, which clears the home indicator.
  /// - On **iOS 14** the native SDK ignores this value entirely (its inset
  ///   modifier requires iOS 15+), so nothing extra is reserved there.
  final double bottomSafeAreaInset;

  /// The initial screen to display when the view mounts.
  ///
  /// Defaults to `null`, which the native bridges treat as
  /// [OctopusInitialScreen.mainFeed]. Use [OctopusInitialScreen.post] /
  /// [OctopusInitialScreen.group] to open a post or group in **bridge mode**
  /// (single-screen entry with no main-feed back navigation), or
  /// [OctopusInitialScreen.createPost] to open the post editor.
  ///
  /// **Precedence.** When a non-null [notification] also carries a non-empty
  /// `linkPath`, the deep link wins and [initialScreen] is ignored.
  ///
  /// Enforcement lives on the native side: the Dart layer emits both
  /// `linkPath` and `initialScreen` in the platform-view creation params
  /// (see [OctopusSDK.creationParamsFor]); each native bridge then falls
  /// back to the main feed when `linkPath` is non-empty (Android
  /// `OctopusEmbeddedView.Factory.create`; iOS `OctopusEmbeddedView` init).
  /// This sidesteps iOS's native notification handler that would otherwise
  /// still reroute on top of the requested initial screen.
  final OctopusInitialScreen? initialScreen;

  /// Optional widget rendered as a Flutter overlay at the **top-LEFT** of
  /// the SDK surface — the iOS-native location for a back chevron when the
  /// SDK is hosted as a pushed route.
  ///
  /// **Why this is a Flutter overlay rather than a native nav-bar item.**
  /// The native iOS SDK's `OctopusHomeScreen` only renders a back chevron
  /// when its SwiftUI tree has a navigation parent (i.e. it has been pushed
  /// into a `NavigationStack`). In Flutter, the SDK is hosted inside a
  /// `UiKitView` mounted as a subview, with no SwiftUI navigation context,
  /// so the native back chevron never renders at root. This overlay lets
  /// the host inject one (typically `IconButton(Icons.arrow_back_ios_new)`
  /// or a custom widget) so a route-hosted SDK still has a left-side
  /// dismissal affordance on iOS.
  ///
  /// **Platform notes.** On Android the native SDK already renders its own
  /// back arrow at top-left when [showBackButton] is `true`, calling
  /// [onBack]; hosts targeting both platforms should pass this widget only
  /// on iOS (or hide the SDK's back via `showBackButton: false` and rely on
  /// the Flutter overlay across both platforms).
  ///
  /// **Placement.** Drawn inside a `Stack` above the embedded native view,
  /// padded by the system top safe area so it lands within the native
  /// nav-bar's left edge. The widget is hit-tested before the native view
  /// receives the tap.
  final Widget? leadingWidget;

  /// Optional widget rendered as a Flutter overlay at the **top-RIGHT** of
  /// the SDK surface — typically a "Close" / X button when the SDK is
  /// hosted in a modal.
  ///
  /// **Why this is a Flutter overlay rather than a native nav-bar item.**
  /// The native iOS SDK's `OctopusHomeScreen` exposes a built-in close
  /// button (`closeModalButton`) — but only when its SwiftUI tree is
  /// natively presented via `.sheet`/`.fullScreenCover`. In Flutter, the
  /// SDK is hosted inside a `UiKitView` mounted as a subview, not via
  /// SwiftUI's modal presentation, so `presentationMode.isPresented` is
  /// `false` and the native close button never renders. This overlay lets
  /// the host inject an X (or any custom widget) on top of the SDK's
  /// surface so the modal remains dismissable on both platforms regardless
  /// of how it's presented from Flutter.
  ///
  /// **Placement.** Same Stack overlay pattern as [leadingWidget], pinned
  /// to the top-right edge with system safe-area padding. Typically used
  /// with `IconButton(Icons.close)`. Hit-tested before the native view.
  ///
  /// **Behaviour.** Both overlays are purely additive: leave them `null`
  /// to keep the existing surface unchanged. Set them when the host needs
  /// to give the user an explicit dismissal affordance — typically wired
  /// to the same callback as [onBack] (which is also fired by the SDK's
  /// own back arrow on Android).
  ///
  /// **Visibility gating.** Both overlays are auto-hidden when the SDK
  /// navigates away from the main feed (post detail, group detail, …) so
  /// they don't visually collide with the SDK's own back chevron and
  /// action menu on deeper screens. The gating listens to the SDK's
  /// `screenDisplayed` event stream.
  final Widget? trailingWidget;

  /// Which navigation container the **native iOS** SDK uses internally for
  /// its sub-navigation. Defaults to [OctopusNavigationMode.navigationStack].
  ///
  /// The Flutter wrapper's default deliberately differs from the native iOS
  /// default ([OctopusNavigationMode.automatic], currently the legacy
  /// `NavigationView`): every Flutter host is by definition a UIKit-hosted
  /// reparented presentation, and the legacy `NavigationView` **will**
  /// silently drop sub-navigation pushes there (a post tap not opening its
  /// detail, a "Yes" confirmation that leaves a sub-screen in place, …).
  /// Pass [OctopusNavigationMode.automatic] explicitly to opt back into the
  /// native default.
  ///
  /// **iOS-only** (wrapped iOS SDK 1.12.2+). On Android this is a no-op — the
  /// native bridge already uses a Compose `NavHost` that keeps its back stack
  /// across modal hosting. See [OctopusNavigationMode].
  final OctopusNavigationMode navigationMode;

  /// Requests a native host-driven leading nav-bar button (close or back) on
  /// the SDK's **root** screen, whose tap fires [onBack]. Defaults to `null`
  /// (no override — each platform keeps its existing root leading icon).
  ///
  /// Use this to give a Flutter-hosted modal an always-available dismiss
  /// affordance: the SDK paints the matching native button and routes its tap
  /// to [onBack] (which your host wires to pop the route). It supersedes the
  /// [leadingWidget] / [trailingWidget] Flutter overlays on iOS — the native
  /// button lives inside the SDK's own nav bar, so it never reparents the
  /// embedded `PlatformView` and is hidden automatically on deeper screens.
  ///
  /// **Supported on both platforms:**
  /// - **Android** → maps to the native
  ///   `OctopusHomeScreen(leadingNavigationIcon:)` (wrapped native SDK 1.12.1+).
  ///   When set, the requested icon (close / back) overrides the root leading
  ///   icon regardless of [showBackButton]; when `null`, the native default
  ///   (a back arrow gated by [showBackButton]) is preserved. Use
  ///   [OctopusNavBarLeadingAction.close] for a Close (X) the back arrow can't
  ///   express.
  /// - **iOS** → maps to the native `OctopusHomeScreen(navBarLeadingAction:)`
  ///   (wrapped iOS SDK 1.12.2+) — the iOS SDK paints no root dismiss button
  ///   for a Flutter-hosted `UiKitView` otherwise. When `null`, the bridge
  ///   backfills to `.back` if [showBackButton] is `true`.
  ///
  /// See [OctopusNavBarLeadingAction].
  final OctopusNavBarLeadingAction? navBarLeadingAction;

  const OctopusHomeScreen({
    super.key,
    this.navBarTitle,
    this.navBarPrimaryColor = false,
    this.showBackButton = true,
    this.titleCentered = false,
    this.theme,
    this.showLoadingIndicator = true,
    this.loadingWidget,
    this.errorWidget,
    this.showError = true,
    this.enabled = true,
    this.onNavigateToLogin,
    this.onModifyUser,
    this.onNavigateToProfile,
    this.onBack,
    this.onNavigateToUrl,
    this.notification,
    this.bottomSafeAreaInset = 0,
    this.initialScreen,
    this.leadingWidget,
    this.trailingWidget,
    this.navigationMode = OctopusNavigationMode.navigationStack,
    this.navBarLeadingAction,
  });

  @override
  State<OctopusHomeScreen> createState() => _OctopusHomeScreenState();
}

class _OctopusHomeScreenState extends State<OctopusHomeScreen> {
  StreamSubscription<Map<String, dynamic>>? _eventSubscription;

  /// Whether the SDK is currently showing the main feed (root screen).
  ///
  /// Used to gate the leading/trailing Flutter overlays: deeper SDK screens
  /// (post detail, group detail, settings, …) render their own back chevron
  /// at top-left AND their own action menu at top-right, so a persistent
  /// host overlay would visually collide with them.
  ///
  /// **Initial value.** `true` when no [OctopusHomeScreen.initialScreen]
  /// override is set — the SDK boots into the main feed in that case.
  /// `false` when the host opens directly into a deeper screen (`post`,
  /// `group`, `createPost`); the overlay must not paint over the SDK's
  /// own chrome on the first frame, and a `screenDisplayed(mainFeed)`
  /// event flips us back to `true` if the SDK ever reports the main feed.
  ///
  /// **Limitation — forward-only events (1.12.0, both platforms).** The
  /// native SDKs emit `screenDisplayed` on forward navigation only; no
  /// event fires when the user pops BACK to the main feed (verified
  /// empirically on Android and iOS). Once the user
  /// navigates deep, the overlays therefore do not reappear until the
  /// widget remounts. Hosts needing a guaranteed dismissal affordance
  /// should keep their own chrome around the view (or
  /// `showBackButton: true` on Android) rather than rely on a
  /// [OctopusHomeScreen.trailingWidget] close button alone.
  ///
  /// **Limitation — process-global SDK event stream.** The listener
  /// subscribes to [OctopusSDK.eventStream], which is shared across the
  /// process. When multiple [OctopusHomeScreen] widgets coexist (e.g. an
  /// embedded tab and an open modal at the same time), a `screenDisplayed`
  /// event fired by one instance is observed by **all** instances. Hosts
  /// that surface overlays on more than one [OctopusHomeScreen]
  /// simultaneously should be aware that visibility gating is shared.
  late bool _isAtRootScreen = widget.initialScreen == null;

  @override
  void initState() {
    super.initState();

    // Listen for events from native code
    _eventSubscription = OctopusSDK.eventStream.listen(
      (event) {
        if (event['event'] == 'loginRequired') {
          widget.onNavigateToLogin?.call();
        } else if (event['event'] == 'editUser') {
          final fieldToEdit = event['fieldToEdit'] as String?;
          widget.onModifyUser?.call(fieldToEdit);
        } else if (event['event'] == 'navigateToUrl') {
          final url = event['url'] as String?;
          if (url != null) {
            widget.onNavigateToUrl?.call(url);
          }
        } else if (event['event'] == 'navigateToProfile') {
          // The native side only emits this when the host opted in, and never
          // with a null id (a member without a client user id opens the Octopus
          // activity screen instead), but stay defensive: a malformed payload
          // must not reach the host as a null-cast crash.
          final clientUserId = event['clientUserId'];
          if (clientUserId is String && clientUserId.isNotEmpty) {
            widget.onNavigateToProfile?.call(clientUserId);
          }
        } else if (event['event'] == 'backRequested') {
          widget.onBack?.call();
        } else if (event['event'] == 'sdkEvent' &&
            event['type'] == 'screenDisplayed') {
          // The native side emits `{event:sdkEvent, type:screenDisplayed,
          // screen:{type:..., …}}` whenever the active SDK screen changes.
          // We only care about whether the user is on the main feed (root)
          // or somewhere deeper; the leading/trailing overlays follow that.
          final screen = event['screen'];
          final screenType = screen is Map ? screen['type'] as String? : null;
          final isRoot = screenType == 'mainFeed';
          if (mounted && isRoot != _isAtRootScreen) {
            setState(() => _isAtRootScreen = isRoot);
          }
        }
      },
      onError: (error) {
        debugPrint('OctopusHomeScreen: event stream error: $error');
      },
    );
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const SizedBox.shrink();
    }

    final embedded = OctopusSDK.embeddedView(
      navBarTitle: widget.navBarTitle,
      navBarPrimaryColor: widget.navBarPrimaryColor,
      showBackButton: widget.showBackButton,
      titleCentered: widget.titleCentered,
      theme: widget.theme,
      interceptUrls: widget.onNavigateToUrl != null,
      interceptProfileTaps: widget.onNavigateToProfile != null,
      hasModifyUserHandler: widget.onModifyUser != null,
      notification: widget.notification,
      bottomSafeAreaInset: widget.bottomSafeAreaInset,
      initialScreen: widget.initialScreen,
      navigationMode: widget.navigationMode,
      navBarLeadingAction: widget.navBarLeadingAction,
    );

    final leading = widget.leadingWidget;
    final trailing = widget.trailingWidget;

    // Only paint the host overlays while the SDK is on the main feed.
    // Deeper SDK screens (post detail, group detail, …) render their own
    // back chevron + action menu in the same edges, so persisting the host
    // overlay would visually collide with them. The native back arrow
    // already pops the SDK stack on both platforms. (See the
    // `_isAtRootScreen` doc for the forward-only event limitation:
    // the overlays do not currently reappear after a back-pop to the feed.)
    //
    // CRITICAL: the tree SHAPE must stay identical across rebuilds. The
    // embedded child hosts a native PlatformView; returning `embedded` bare
    // in one build and `Stack(Positioned.fill(embedded), …)` in the next
    // reparents the PlatformView, which disposes and recreates the native
    // view — the SDK then restarts on its main feed, silently swallowing
    // the sub-navigation the user just performed (the 1.12.0-dev "modal
    // sub-navigation drop" report). So the Stack +
    // Positioned.fill wrapper is applied UNCONDITIONALLY — across
    // `_isAtRootScreen` flips AND across the host toggling
    // `leadingWidget`/`trailingWidget` between null and non-null — and only
    // the overlay children themselves come and go. (A Stack whose children
    // are all positioned sizes to the incoming constraints, exactly like
    // the bare platform view, so the wrapper is layout-neutral.)
    final showOverlays = _isAtRootScreen;

    // Stack host-provided overlay affordances on top of the native nav bar.
    // `SafeArea` (top only) pads down by the system top inset so the widgets
    // land within the native top bar's edges regardless of notch /
    // status-bar height. A `Material` ancestor lets the inner widget take
    // advantage of Material InkResponse / IconButton ripples without the
    // host having to wrap it themselves.
    Widget overlay(Widget child) => SafeArea(
          bottom: false,
          left: false,
          right: false,
          child: Material(type: MaterialType.transparency, child: child),
        );
    return Stack(
      children: [
        Positioned.fill(child: embedded),
        if (showOverlays && leading != null)
          Positioned(top: 0, left: 0, child: overlay(leading)),
        if (showOverlays && trailing != null)
          Positioned(top: 0, right: 0, child: overlay(trailing)),
      ],
    );
  }
}
