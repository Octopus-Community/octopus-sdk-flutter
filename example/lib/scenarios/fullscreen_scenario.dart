import 'dart:async';

import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../auth/login_page.dart';
import '../auth/profile_edit_page.dart';
import '../octopus_demo_config.dart';
import '../widgets/scenario_scaffold.dart';

/// Fullscreen scenario — host integration mode where the SDK's
/// [OctopusHomeScreen] is a **first-class navigation destination**: a
/// standard [MaterialPageRoute] push, mirror of the Android sample's
/// `CommunityFullScreenRoute` (a `composable<…>` destination inside the
/// host's `NavHost`).
///
/// One of the three presentation shapes the sample demos side by side:
/// **Modal** (`fullscreenDialog` route, slide-up on iOS, native SDK close
/// button), **Fullscreen** (this scenario — standard push), and
/// **Sheet** (`showModalBottomSheet` at 90% height).
///
/// **Why this is different from the Modal scenario.**
/// - The fullscreen route behaves like any other screen in the host's
///   navigation stack: the user pushes into it (lateral / platform-default
///   transition) and pops out via the SDK's own back arrow, the system
///   back gesture, or — on iOS — the swipe-from-left-edge that
///   [MaterialPageRoute] enables by default. No tap-outside-to-dismiss, no
///   drag handle, no explicit close button.
/// - The Modal scenario sets `fullscreenDialog: true` instead, which
///   presents with the modal slide-up transition on iOS, disables the iOS
///   swipe-back gesture, and shows the SDK's native close button on iOS
///   (`navBarLeadingAction: close`) so the modal stays dismissable.
///
/// **Inline push vs `OctopusSDK.showOctopusHomeScreen`.** The public
/// helper pushes this exact route shape (`Scaffold` +
/// `SafeArea(bottom: false)` + [OctopusHomeScreen] in a plain
/// [MaterialPageRoute]) — use it for the one-liner. The scenario keeps the
/// inline form because it forwards the device bottom inset — not a helper
/// parameter — and to keep the full route shape visible as copyable
/// reference code.
///
/// **Why no host `AppBar` wrapping it.** The SDK renders its own native
/// top bar ([OctopusHomeScreen] → M3 `OctopusTopAppBar` on Android,
/// `UINavigationBar` on iOS) for the home view AND for every deeper SDK
/// screen. Adding a Flutter `AppBar` here would stack two headers — the
/// same reason the Community tab drops the host `AppBar` (see `main.dart`).
///
/// **Bottom inset.** The route hosts the SDK PlatformView edge-to-edge
/// (`SafeArea(bottom: false)`), so the host forwards the device's bottom
/// gesture-area inset via `bottomSafeAreaInset` — the SDK's floating
/// "Write a post" pill then clears the gesture pill (Android edge-to-edge,
/// API 35+) / home indicator (iOS). `viewPadding` reports the physical
/// inset regardless of upstream SafeArea consumption.
///
/// **Back routing.** `onBack` pops this route's `Navigator` — the SDK's
/// back arrow therefore means "leave Octopus and go back to where I was",
/// the same semantics as the Modal scenario's native close button.
///
/// **Login + profile-edit routing.** Both callbacks resolve `Navigator.of`
/// against the pushed route's `BuildContext`, so the Flutter login /
/// profile-edit pages stack ABOVE the SDK route; popping returns here with
/// the freshly-connected session (the SDK observes `OctopusSDK.profile`
/// and re-renders automatically).
///
/// *History note*: during 1.12.0 development a report claimed modal-style
/// routes silently dropped SDK sub-navigation; the root cause turned out
/// to be the overlay gating reparenting the PlatformView (fixed in
/// `octopus_home_screen.dart` — the tree shape is now stable), not the
/// route shape. History in `octopus-sdk-flutter#63`.
class FullscreenScenario extends StatelessWidget {
  const FullscreenScenario({super.key});

  @override
  Widget build(BuildContext context) {
    // Opens the SDK as a full-screen route. [deepLink] true forces the bundled
    // sample notification so this presentation mode's deep-link can be verified
    // on its own (no live push needed — the live push path always routes to the
    // Community tab); false honours an active push deep link, else opens root.
    Future<void> open(
      ScenarioResultSink setResult, {
      bool deepLink = false,
    }) async {
      try {
        demoLog.apiCall('Navigator.push<OctopusHomeScreen>', {
          'fullscreenDialog': false,
          'deepLink': deepLink,
        });
        final app = AppScope.of(context);
        // Resolve the navigator before any await so we don't keep the outer
        // BuildContext across an async gap.
        final navigator = Navigator.of(context);
        // Capture the device's bottom gesture-area inset against the launching
        // context before the push. Read off the raw View (immune to ancestor
        // SafeArea / bottom-nav removePadding, which zeroes viewPadding.bottom).
        final bottomSafeArea = MediaQueryData.fromView(
          View.of(context),
        ).viewPadding.bottom;
        final notification = deepLink
            ? OctopusSDK.getOctopusNotification(
                sampleOctopusNotificationPayload,
              )
            : app.pendingCommunityNotification;
        setResult(
          deepLink
              ? 'Fullscreen route opened (deep-linked to sample post).'
              : 'Fullscreen route opened.',
        );
        unawaited(
          navigator.push(
            MaterialPageRoute<void>(
              builder: (routeContext) => Scaffold(
                body: SafeArea(
                  bottom: false,
                  child: OctopusHomeScreen(
                    theme: app.effectiveOctopusTheme(),
                    navBarTitle: 'Community',
                    navBarPrimaryColor: false,
                    showBackButton: true,
                    bottomSafeAreaInset: bottomSafeArea,
                    // Deep-link target for this mode: the sample post for
                    // Preset 2, an active push deep link otherwise. Mirrors the
                    // Community tab's `notification:` wiring. Read at mount only
                    // (PlatformView creationParams), which is fine — the route
                    // is freshly pushed each time.
                    notification: notification,
                    onBack: () => Navigator.of(routeContext).pop(),
                    onNavigateToLogin: () => Navigator.of(routeContext).push(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    ),
                    onModifyUser: (field) => Navigator.of(routeContext).push(
                      MaterialPageRoute(
                        builder: (_) => ProfileEditPage(fieldToEdit: field),
                      ),
                    ),
                    onNavigateToUrl: (url) {
                      demoLog.apiCall('onNavigateToUrl', {
                        'url': url,
                        'mode': 'fullscreen',
                      });
                      ScaffoldMessenger.of(routeContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Navigate to URL (handled by app): $url',
                          ),
                        ),
                      );
                      return UrlOpeningStrategy.handledByApp;
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      } catch (e) {
        setResult('Fullscreen scenario failed: $e', isError: true);
      }
    }

    return ScenarioScaffold(
      title: 'Fullscreen',
      description:
          'Open the SDK as a dedicated full-screen destination — a standard '
          'MaterialPageRoute push hosting OctopusHomeScreen (the same shape '
          'the showOctopusHomeScreen helper uses). Behaves like any other '
          'screen in the navigation stack: closes via the SDK back arrow, '
          'Android system back, or iOS swipe-from-left-edge. Preset 2 opens it '
          'deep-linked to the sample post so this mode can be QA-verified '
          'without a live push.',
      resultTestId: 'fullscreen-result',
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-fullscreen-1',
          label: 'Preset 1 · Open SDK as full-screen route',
          onRun: (setResult) => open(setResult),
        ),
        ScenarioPreset(
          testId: 'qa-preset-fullscreen-2',
          label: 'Preset 2 · Open deep-linked to sample post',
          onRun: (setResult) => open(setResult, deepLink: true),
        ),
      ],
    );
  }
}
