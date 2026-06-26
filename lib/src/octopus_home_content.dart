import 'dart:async';

import 'package:flutter/material.dart';

import 'octopus_initial_screen.dart';
import 'octopus_sdk.dart';
import 'octopus_theme.dart';

/// Embedded variant of [OctopusHomeScreen] that **omits the native SDK
/// navigation chrome** (top app bar) so the host app can render its own.
///
/// Use this when the host already provides a title for the screen — e.g. when
/// the Octopus community lives inside a tabbed shell with a host `AppBar` that
/// already says "Community". The SDK's own title would otherwise stack
/// underneath the host's, producing a double header.
///
/// Mirrors the native Android `OctopusHomeContent` composable.
///
/// ## Platform support — Android only
///
/// The no-navbar mode is an **Android-only** capability by design:
///
/// - **Android**: the SDK mounts `OctopusHomeContent` (no top bar). The SDK's
///   own `NavHost` still drives the internal sub-navigation (post detail,
///   group detail, …), each deep screen rendering its own chrome. Fully
///   supported.
/// - **iOS**: this widget renders the native top bar — **identical to
///   [OctopusHomeScreen]**. A Flutter-side chrome-clean variant is *not*
///   pursued on iOS (the native no-navbar request
///   is deliberately not a goal): the iOS SDK drives its sub-navigation
///   through its own `NavigationStack` top bar, so stripping that bar would
///   leave deep screens (post / group detail) with no back affordance that
///   Flutter could supply. The native top bar is therefore kept as the
///   **single** top chrome on iOS.
///
/// **Recommendation.** For a single-chrome embed that works the same on both
/// platforms, prefer [OctopusHomeScreen] and let its native top bar be the
/// sole top chrome (drop any host `AppBar` above it). Host-side affordances
/// (a close X, a custom back) go through [OctopusHomeScreen.leadingWidget] /
/// [OctopusHomeScreen.trailingWidget] + [OctopusHomeScreen.onBack], which sit
/// inside the native bar's edges rather than adding a second Flutter bar.
/// `OctopusHomeContent` remains useful when the host specifically wants the
/// SDK chrome gone on Android and accepts that iOS keeps the native bar.
///
/// Example usage:
/// ```dart
/// Scaffold(
///   appBar: AppBar(title: const Text('Community')),
///   body: OctopusHomeContent(
///     theme: theme,
///     onNavigateToLogin: () => Navigator.push(context, ...),
///   ),
/// )
/// ```
class OctopusHomeContent extends StatefulWidget {
  /// Custom theme for the interface (colors, font sizes, logo).
  final OctopusTheme? theme;

  /// If `true`, uses the primary color for the navigation bar background.
  ///
  /// Forwarded to the iOS bridge as long as the iOS pod 1.12.0 still renders
  /// its own top bar (see "Platform parity" above). Ignored on Android, where
  /// `OctopusHomeContent` has no top bar.
  final bool navBarPrimaryColor;

  /// Whether the widget is enabled (renders) — `false` renders an empty box.
  final bool enabled;

  /// Callback function called when the user navigates to login.
  final VoidCallback? onNavigateToLogin;

  /// Callback function called when the user wants to modify their profile.
  ///
  /// The parameter is the field that has been asked to be edited by the user.
  /// Null if the user tapped on "Edit my profile".
  final Function(String?)? onModifyUser;

  /// Callback function called when a URL is tapped inside the Octopus
  /// Community UI.
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

  /// Extra bottom inset (logical pixels) the native screen reserves at the
  /// bottom so its floating "Write a post" pill sits above the host app's own
  /// bottom chrome (e.g. a Flutter `BottomNavigationBar`).
  ///
  /// Default `0` — relies on the embedded PlatformView already living above
  /// the host bottom chrome (the standard Material `Scaffold` body case).
  /// Increase only when the host renders something below the SDK view that
  /// the SDK should not overlap.
  final double bottomSafeAreaInset;

  /// The initial screen to display when the view mounts.
  ///
  /// Defaults to `null`, which the native bridges treat as
  /// [OctopusInitialScreen.mainFeed]. See [OctopusHomeScreen.initialScreen]
  /// for the full contract — including the precedence rule that a
  /// notification deep link wins over [initialScreen] at mount time.
  final OctopusInitialScreen? initialScreen;

  const OctopusHomeContent({
    super.key,
    this.theme,
    this.navBarPrimaryColor = false,
    this.enabled = true,
    this.onNavigateToLogin,
    this.onModifyUser,
    this.onNavigateToUrl,
    this.notification,
    this.bottomSafeAreaInset = 0,
    this.initialScreen,
  });

  @override
  State<OctopusHomeContent> createState() => _OctopusHomeContentState();
}

class _OctopusHomeContentState extends State<OctopusHomeContent> {
  StreamSubscription<Map<String, dynamic>>? _eventSubscription;

  @override
  void initState() {
    super.initState();

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
        }
      },
      onError: (error) {
        debugPrint('OctopusHomeContent: event stream error: $error');
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

    return OctopusSDK.embeddedView(
      theme: widget.theme,
      navBarPrimaryColor: widget.navBarPrimaryColor,
      interceptUrls: widget.onNavigateToUrl != null,
      notification: widget.notification,
      bottomSafeAreaInset: widget.bottomSafeAreaInset,
      showNavBar: false,
      initialScreen: widget.initialScreen,
    );
  }
}
