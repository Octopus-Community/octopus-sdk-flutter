import 'package:flutter/material.dart';

import 'octopus_initial_screen.dart';
import 'octopus_sdk.dart';
import 'octopus_theme.dart';

/// A Flutter widget that opens a single group's feed in the native Octopus
/// UI in **bridge mode** — the user cannot navigate to other groups or the
/// main community feed from this entry point.
///
/// Equivalent to [OctopusHomeScreen] with
/// `initialScreen: OctopusInitialScreen.group(GroupScreenInfo(groupId: ...))`
/// — provided as a dedicated widget for callers who want a clearer
/// per-screen entry point. Mirrors the Android `OctopusGroupDetailsScreen` /
/// `OctopusGroupDetailsContent` composables and the iOS
/// `OctopusInitialScreen.group(...)` enum case.
///
/// ## Back navigation
///
/// Pass [onBack] (typically `() => Navigator.of(context).pop()`) to wire
/// the SDK back chevron tap to a host route pop. iOS swipe-from-left and
/// Android system back already pop the `MaterialPageRoute` directly —
/// they don't traverse [onBack], so they keep working independently of
/// whether you set it. Without [onBack] the SDK's internal back arrow
/// is inert at the group-detail start destination (Android `navigateUp()`
/// is a no-op on a single-screen back stack; on iOS the chevron is
/// rendered by the bridge's `showBackButton` backfill but the SDK has no
/// callback to invoke without a host-supplied [onBack]).
///
/// Example usage:
/// ```dart
/// Navigator.of(context).push(MaterialPageRoute(
///   builder: (routeContext) => OctopusGroupDetailsScreen(
///     groupId: group.id,
///     theme: theme,
///     onBack: () => Navigator.of(routeContext).pop(),
///     onNavigateToLogin: () => Navigator.push(context, ...),
///   ),
/// ));
/// ```
class OctopusGroupDetailsScreen extends StatelessWidget {
  /// The id of the group to display. Required.
  final String groupId;

  /// Custom theme for the interface (colors, font sizes, logo).
  final OctopusTheme? theme;

  /// Title displayed in the navigation bar (iOS replaces the logo; Android
  /// shows alongside).
  final String? navBarTitle;

  /// If true, uses the primary color for the navigation bar background.
  final bool navBarPrimaryColor;

  /// If true, shows the back button in the navigation bar (Android only).
  final bool showBackButton;

  /// Whether the widget is enabled (renders) — `false` renders an empty box.
  final bool enabled;

  /// Invoked when the user taps the SDK back chevron (or fires
  /// `backRequested` on iOS via `navBarLeadingAction` semantics). Wire to
  /// `Navigator.of(context).pop()` to dismiss the hosting route. Without
  /// it the back chevron is inert at the group-detail start destination —
  /// the host must use its own AppBar back button or rely on iOS
  /// swipe-from-left / Android system back.
  final VoidCallback? onBack;

  /// Callback function called when the user navigates to login.
  final VoidCallback? onNavigateToLogin;

  /// Callback function called when the user wants to modify their profile.
  ///
  /// The parameter is the field that has been asked to be edited by the
  /// user, or `null` if the user tapped on "Edit my profile".
  final Function(String?)? onModifyUser;

  /// Callback function called when a URL is tapped inside the Octopus
  /// Community UI. See [OctopusHomeScreen.onNavigateToUrl] for the full
  /// contract.
  final UrlOpeningStrategy Function(String)? onNavigateToUrl;

  /// Callback invoked when the user taps any profile inside the community, so
  /// your app can open its own profile screen for that member ("Unified
  /// Profile"). See [OctopusHomeScreen.onNavigateToProfile] for the full
  /// contract — it is opt-in, mount-time, and gated on the community exposing
  /// client user ids.
  final void Function(String clientUserId)? onNavigateToProfile;

  /// Push notification whose deep-link target the native view should open.
  /// When supplied with a non-empty `linkPath`, the deep link wins and the
  /// group pointed at by [groupId] is **not** mounted — matching
  /// [OctopusHomeScreen]'s precedence rule.
  final OctopusNotification? notification;

  /// Total bottom padding (logical pixels) the native screen reserves at the
  /// bottom. Defaults to `0`, which resolves the padding from where this widget
  /// is mounted rather than reserving nothing. See
  /// [OctopusHomeScreen.bottomSafeAreaInset] for the full contract.
  final double bottomSafeAreaInset;

  const OctopusGroupDetailsScreen({
    super.key,
    required this.groupId,
    this.theme,
    this.navBarTitle,
    this.navBarPrimaryColor = false,
    this.showBackButton = true,
    this.enabled = true,
    this.onBack,
    this.onNavigateToLogin,
    this.onModifyUser,
    this.onNavigateToUrl,
    this.onNavigateToProfile,
    this.notification,
    this.bottomSafeAreaInset = 0,
  });

  @override
  Widget build(BuildContext context) {
    return OctopusHomeScreen(
      theme: theme,
      navBarTitle: navBarTitle,
      navBarPrimaryColor: navBarPrimaryColor,
      showBackButton: showBackButton,
      enabled: enabled,
      onBack: onBack,
      onNavigateToLogin: onNavigateToLogin,
      onModifyUser: onModifyUser,
      onNavigateToUrl: onNavigateToUrl,
      onNavigateToProfile: onNavigateToProfile,
      notification: notification,
      bottomSafeAreaInset: bottomSafeAreaInset,
      initialScreen: OctopusInitialScreen.group(
        GroupScreenInfo(groupId: groupId),
      ),
    );
  }
}
