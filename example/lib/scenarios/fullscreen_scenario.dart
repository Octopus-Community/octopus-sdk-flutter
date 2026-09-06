import 'dart:async';

import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../auth/login_page.dart';
import '../auth/profile_edit_page.dart';
import '../octopus_demo_config.dart';
import '../widgets/scenario_scaffold.dart';

/// Height of the fake host bottom bar used by Preset 3.
///
/// Fixed rather than measured so the expected padding is arithmetic a QA pass
/// can check by eye: the SDK's "Write a post" pill must clear
/// `_kHostBarHeight + viewPadding.bottom`.
const double _kHostBarHeight = 56;

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
///   swipe-back gesture, and shows the SDK's native close button
///   (`navBarLeadingAction: close`) on both platforms so the modal stays
///   dismissable.
///
/// **Inline push vs `OctopusSDK.showOctopusHomeScreen`.** The public
/// helper pushes this exact route shape (`Scaffold` +
/// `SafeArea(bottom: false)` + [OctopusHomeScreen] in a plain
/// [MaterialPageRoute]) — use it for the one-liner. The bottom inset is
/// **not** a reason to stay inline: since 1.12.3 the helper exposes
/// `bottomSafeAreaInset`, and left `null` it auto-reserves the launching
/// view's bottom safe area. The scenario keeps the inline form to leave the
/// full route shape visible as copyable reference code, and because Preset 3
/// composes a host bottom bar into the route (`extendBody` +
/// `bottomNavigationBar`), which is beyond the helper's fixed route shape.
///
/// **Why no host `AppBar` wrapping it.** The SDK renders its own native
/// top bar ([OctopusHomeScreen] → M3 `OctopusTopAppBar` on Android,
/// `UINavigationBar` on iOS) for the home view AND for every deeper SDK
/// screen. Adding a Flutter `AppBar` here would stack two headers — the
/// same reason the Community tab drops the host `AppBar` (see `main.dart`).
///
/// **Bottom inset.** The route hosts the SDK PlatformView edge-to-edge
/// (`SafeArea(bottom: false)`), so something has to reserve the bottom band for
/// the SDK's floating "Write a post" pill to clear the gesture pill (Android
/// edge-to-edge, API 35+) / home indicator (iOS).
///
/// **Presets 1 and 2 request nothing at all** and let the widget resolve it from
/// its mount point — the documented default since 1.13, and the only place in the
/// sample that exercises that path. On Android it resolves the same device inset
/// this scenario used to compute by hand; on iOS the widget does not resolve, so
/// the bridge applies its own default instead.
///
/// **Preset 3** is the only scenario left that computes a value, and the only one
/// where the requested total exceeds the safe area the view sits in: it adds a
/// host bottom bar over the embedded view and requests `bar height + inset`, which
/// is the shape the parameter documents and the one that catches a bridge adding
/// instead of totalling. It reads the *raw View's* `viewPadding`, which reports the
/// physical inset regardless of upstream SafeArea consumption — the inherited
/// `MediaQuery`'s does not (`MediaQueryData.removePadding` subtracts
/// `padding.bottom` from it).
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
/// route shape. History tracked internally.
class FullscreenScenario extends StatelessWidget {
  const FullscreenScenario({super.key});

  @override
  Widget build(BuildContext context) {
    // Opens the SDK as a full-screen route. [deepLink] true forces the bundled
    // sample notification so this presentation mode's deep-link can be verified
    // on its own (no live push needed — the live push path always routes to the
    // Community tab); false honours an active push deep link, else opens root.
    // [hostBottomBar] true reproduces the documented primary use case for
    // `bottomSafeAreaInset`: a host bottom bar the SDK must clear, with the
    // embedded view running *behind* it (`extendBody: true`) so the view really
    // sits in the device safe area. That is the only shape where the requested
    // total exceeds the system inset, so it is the only one that can catch a
    // normalization mistake; left false, this preset instead exercises the 1.13
    // auto-resolution path by requesting nothing at all.
    Future<void> open(
      ScenarioResultSink setResult, {
      bool deepLink = false,
      bool hostBottomBar = false,
    }) async {
      try {
        demoLog.apiCall('Navigator.push<OctopusHomeScreen>', {
          'fullscreenDialog': false,
          'deepLink': deepLink,
          'hostBottomBar': hostBottomBar,
        });
        final app = AppScope.of(context);
        // Resolve the navigator before any await so we don't keep the outer
        // BuildContext across an async gap.
        final navigator = Navigator.of(context);
        // Capture the device's bottom gesture-area inset against the launching
        // context before the push. Read off the raw View, which bypasses the
        // inherited MediaQuery: in a host tree, a `SafeArea` — or a `Scaffold`
        // with a `bottomNavigationBar` — would run
        // `MediaQueryData.removePadding`, which zeroes `padding.bottom` AND
        // subtracts it from `viewPadding.bottom`. The inherited value is
        // therefore not a reliable source for the physical inset; the View's is.
        final bottomSafeArea = MediaQueryData.fromView(
          View.of(context),
        ).viewPadding.bottom;
        // Total bottom padding to request. With a host bar drawn over the
        // embedded view, that total is the bar's height *plus* the safe area the
        // view sits in — the value the docs tell hosts to pass, and the same one
        // Android and iOS must now both honour.
        //
        // Without a host bar, request nothing and let the widget resolve it —
        // the documented default since 1.13, and what exercises the auto path in
        // the sample. On Android that resolves the same device inset this
        // scenario used to compute by hand, so the result is unchanged there.
        // On iOS the widget does NOT resolve: the key is dropped and the bridge
        // applies its historical 10 pt instead of the 0.01 pt that an explicitly
        // passed device inset normalizes to, so the pill sits 10 pt higher on iOS
        // than it did when this preset computed the value itself. Deliberate.
        final requestedInset = hostBottomBar
            ? _kHostBarHeight + bottomSafeArea
            : 0.0;
        final notification = deepLink
            ? OctopusSDK.getOctopusNotification(
                sampleOctopusNotificationPayload,
              )
            : app.pendingCommunityNotification;
        setResult(
          hostBottomBar
              ? 'Fullscreen route opened behind a ${_kHostBarHeight.toInt()} pt '
                    'host bar — requested '
                    '${requestedInset.toStringAsFixed(0)} pt total bottom '
                    'padding. The "Write a post" pill must sit above the bar.'
              : deepLink
              ? 'Fullscreen route opened (deep-linked to sample post).'
              : 'Fullscreen route opened.',
        );
        unawaited(
          navigator.push(
            MaterialPageRoute<void>(
              builder: (routeContext) => Scaffold(
                // Draw the body behind the host bar so the embedded view really
                // reaches the bottom of the screen; without this the Scaffold
                // lays the body out above the bar, the view's own safe area
                // drops to 0, and the case degenerates back to R == S.
                extendBody: hostBottomBar,
                // Fed the SAME value that was requested, so "the bar's height
                // equals the requested total" is structural rather than two
                // independent computations that happen to agree.
                bottomNavigationBar: hostBottomBar
                    ? _HostBottomBar(totalHeight: requestedInset)
                    : null,
                body: SafeArea(
                  bottom: false,
                  child: OctopusHomeScreen(
                    theme: app.effectiveOctopusTheme(),
                    navBarTitle: 'Community',
                    navBarPrimaryColor: false,
                    showBackButton: true,
                    bottomSafeAreaInset: requestedInset,
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
      api: 'showOctopusHomeScreen',
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
        ScenarioPreset(
          testId: 'qa-preset-fullscreen-3',
          label: 'Preset 3 · Behind a host bottom bar (clears bar + inset)',
          onRun: (setResult) => open(setResult, hostBottomBar: true),
        ),
      ],
    );
  }
}

/// Opaque stand-in for a host app's bottom navigation bar (Preset 3).
///
/// Deliberately opaque and labelled: the point of the preset is to see whether
/// the SDK's floating "Write a post" pill ends up *behind* this bar. A
/// translucent bar would hide the very failure it exists to expose.
class _HostBottomBar extends StatelessWidget {
  const _HostBottomBar({required this.totalHeight});

  /// The band this bar occupies — the same value the scenario requested via
  /// `bottomSafeAreaInset`, passed in rather than recomputed so the preset's
  /// invariant cannot drift if an ancestor consumes the bottom padding.
  final double totalHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: totalHeight,
      color: Theme.of(context).colorScheme.primaryContainer,
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: _kHostBarHeight,
        child: Center(
          child: Text(
            'Host bottom bar (${_kHostBarHeight.toInt()} pt)',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ),
    );
  }
}
