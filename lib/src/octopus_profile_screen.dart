import 'package:flutter/material.dart';

import 'octopus_initial_screen.dart';
import 'octopus_nav_bar_leading_action.dart';
import 'octopus_sdk.dart';
import 'octopus_theme.dart';

/// A Flutter widget that opens a member's Octopus profile — or, with
/// [clientUserId] left `null`, the connected user's own profile — without going
/// through the community feed.
///
/// This is the screen a "Unified Profile" host needs: once you intercept every
/// profile tap with [OctopusHomeScreen.onNavigateToProfile], you own the
/// navigation and the SDK shows no profile screen of its own. Push this widget
/// with the `clientUserId` the callback handed you and the member's Octopus
/// profile opens.
///
/// Mirrors the iOS `OctopusProfileScreen` view — whose own documentation names
/// "a Flutter / React Native plugin" as its intended consumer — and the Android
/// `navigateToOctopusProfileByClientUserId` / `CurrentUserProfileGraph`
/// destinations. Equivalent to [OctopusHomeScreen] with
/// `initialScreen: OctopusInitialScreen.profile(clientUserId: ...)`, and
/// provided as a dedicated widget for the same reason
/// [OctopusPostDetailsScreen] is.
///
/// ## Which profile opens
///
/// | [clientUserId] | Screen |
/// |---|---|
/// | `null` | the connected user's **own** profile, with its edit affordances (iOS `OctopusProfileScreen(clientUserId: nil)`, Android `CurrentUserProfileGraph`) |
/// | set | that member's profile, **read-only** (iOS resolves it through the client-user-id lookup, Android via its `ProfileSummary(clientUserId:)` destination) |
/// | blank or whitespace-only | same as `null` — an id with nothing but whitespace in it names nobody |
///
/// Surrounding whitespace in a non-blank id is ignored: `' cu-1 '` opens the
/// same member as `'cu-1'`.
///
/// An id that cannot be resolved — unknown or stale mapping, a network failure,
/// or a community that does not expose client user ids — shows the SDK's
/// unavailable / error state on both platforms. It never silently falls back to
/// the connected user's own profile.
///
/// With no connected user and no [clientUserId], iOS shows the same unavailable
/// state; wire [onNavigateToLogin] to send the user to your sign-in flow.
///
/// ## Back navigation
///
/// Same contract as [OctopusPostDetailsScreen]: pass [onBack] (typically
/// `() => Navigator.of(context).pop()`) to wire the SDK's back affordance to a
/// host route pop. iOS swipe-from-left and Android system back pop the
/// `MaterialPageRoute` directly and keep working regardless.
///
/// Example usage:
/// ```dart
/// OctopusHomeScreen(
///   onNavigateToProfile: (clientUserId) {
///     Navigator.of(context).push(MaterialPageRoute(
///       builder: (routeContext) => OctopusProfileScreen(
///         clientUserId: clientUserId,
///         theme: theme,
///         onBack: () => Navigator.of(routeContext).pop(),
///       ),
///     ));
///   },
/// )
/// ```
///
/// ## Not exposed here, and why
///
/// - **No Octopus-profile-id variant.** Android's native SDK accepts a raw
///   Octopus profile id for this screen, iOS's `OctopusProfileScreen` does not,
///   so the wrapper exposes only the form that works on both. Holding just an
///   Octopus id, open the member's posts instead:
///   `OctopusHomeScreen(initialScreen: OctopusInitialScreen.activity(
///   ActivityScreenInfo.profileId(id)))`.
/// - **No `navBarTitle` / `titleCentered` / `notification`.** The first two
///   configure the community feed's top bar, which this screen does not show;
///   a notification deep link would replace the profile it was asked to open
///   (the deep link always wins over an initial screen). Use
///   [OctopusHomeScreen] for those.
class OctopusProfileScreen extends StatelessWidget {
  /// The host app's own id for the member whose profile to display — the id you
  /// passed to SSO `connectUser`, and the one
  /// [OctopusHomeScreen.onNavigateToProfile] hands you.
  ///
  /// `null` (the default) opens the connected user's own profile.
  final String? clientUserId;

  /// Custom theme for the interface (colors, font sizes, logo).
  final OctopusTheme? theme;

  /// If true (default), shows the SDK's back affordance in the navigation bar.
  /// See [OctopusHomeScreen.showBackButton].
  final bool showBackButton;

  /// Whether the widget is enabled (renders) — `false` renders an empty box.
  final bool enabled;

  /// Invoked when the user taps the SDK's back / close affordance. Wire to
  /// `Navigator.of(context).pop()` to dismiss the hosting route.
  final VoidCallback? onBack;

  /// Callback function called when the user navigates to login.
  final VoidCallback? onNavigateToLogin;

  /// Callback function called when the user wants to modify their profile.
  ///
  /// The parameter is the field the user asked to edit, or `null` if they
  /// tapped "Edit my profile". Only reachable on the connected user's own
  /// profile ([clientUserId] left `null`) — another member's profile is
  /// read-only.
  final Function(String?)? onModifyUser;

  /// Callback function called when a URL is tapped inside the Octopus
  /// Community UI. See [OctopusHomeScreen.onNavigateToUrl] for the full
  /// contract.
  final UrlOpeningStrategy Function(String)? onNavigateToUrl;

  /// Called when the user taps another member's profile from within this
  /// screen. See [OctopusHomeScreen.onNavigateToProfile] for the full contract
  /// — it is opt-in, mount-time, and gated on the community exposing client
  /// user ids.
  ///
  /// Wire it here too when your host runs Unified Profile: leaving it null on
  /// this screen while setting it on the community view is the "one embedded
  /// view at a time" trap documented on [OctopusHomeScreen.onNavigateToProfile]
  /// — on iOS the native switch is a setter on the shared SDK instance, so this
  /// mount would turn interception back off for both.
  final void Function(String clientUserId)? onNavigateToProfile;

  /// Requests a native host-driven leading nav-bar button (close or back) whose
  /// tap fires [onBack]. See [OctopusHomeScreen.navBarLeadingAction].
  ///
  /// **iOS only on this screen.** The native iOS `OctopusProfileScreen` takes
  /// this action directly. On Android the profile destination paints the SDK's
  /// own back chevron, which already routes to [onBack]; the Android bridge
  /// applies `leadingNavigationIcon` to the community feed only.
  final OctopusNavBarLeadingAction? navBarLeadingAction;

  /// Total bottom padding (logical pixels) the native screen reserves at the
  /// bottom. Defaults to `0`. See [OctopusHomeScreen.bottomSafeAreaInset] for
  /// the full contract.
  ///
  /// **Android only on this screen** — the native iOS `OctopusProfileScreen`
  /// has no bottom-inset parameter, so the iOS bridge does not forward it.
  final double bottomSafeAreaInset;

  const OctopusProfileScreen({
    super.key,
    this.clientUserId,
    this.theme,
    this.showBackButton = true,
    this.enabled = true,
    this.onBack,
    this.onNavigateToLogin,
    this.onModifyUser,
    this.onNavigateToUrl,
    this.onNavigateToProfile,
    this.navBarLeadingAction,
    this.bottomSafeAreaInset = 0,
  });

  @override
  Widget build(BuildContext context) {
    return OctopusHomeScreen(
      theme: theme,
      showBackButton: showBackButton,
      enabled: enabled,
      onBack: onBack,
      onNavigateToLogin: onNavigateToLogin,
      onModifyUser: onModifyUser,
      onNavigateToUrl: onNavigateToUrl,
      onNavigateToProfile: onNavigateToProfile,
      navBarLeadingAction: navBarLeadingAction,
      bottomSafeAreaInset: bottomSafeAreaInset,
      initialScreen: OctopusInitialScreen.profile(clientUserId: clientUserId),
    );
  }
}
