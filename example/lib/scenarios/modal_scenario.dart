import 'dart:async';

import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../auth/login_page.dart';
import '../auth/profile_edit_page.dart';
import '../octopus_demo_config.dart';
import '../widgets/scenario_scaffold.dart';

/// Modal scenario — host integration mode where the SDK's
/// [OctopusHomeScreen] is presented as a **full-screen modal**: a
/// `MaterialPageRoute(fullscreenDialog: true)`, the Flutter equivalent of
/// the iOS sample's `ModalOctopusView` (SwiftUI `.fullScreenCover`).
///
/// One of the three presentation shapes the sample demos side by side:
/// **Modal** (this scenario — `fullscreenDialog` route, slide-up on iOS,
/// native SDK close button), **Fullscreen** (standard `MaterialPageRoute`
/// push), and **Sheet** (`showModalBottomSheet` at 90% height).
///
/// **What `fullscreenDialog: true` changes.**
/// - iOS presents the route with the platform's modal slide-up transition
///   (matching `.fullScreenCover`) and **disables** the
///   swipe-from-left-edge back gesture — modals are dismissed explicitly.
/// - Android keeps the platform's default fullscreen-dialog transition;
///   the system back gesture/button still pops the route.
///
/// **Native dismiss + sub-navigation in a modal.** This scenario uses two
/// wrapped-SDK APIs added specifically for modal hosting by Flutter / React
/// Native plugins:
/// - [OctopusHomeScreen.navigationMode] is set to
///   [OctopusNavigationMode.navigationStack] (iOS-only, wrapped iOS SDK
///   1.12.2+). iOS reparents the SDK's hosting controller during a modal
///   presentation; the default legacy `NavigationView` can silently drop
///   sub-navigation pushes there (a post tap not opening its detail), and
///   `navigationStack` keeps them working. No-op on Android (the Compose
///   `NavHost` keeps its back stack already).
/// - [OctopusHomeScreen.navBarLeadingAction] is set to
///   [OctopusNavBarLeadingAction.close], so the SDK paints a **native close
///   button** inside its own nav bar whose tap fires [onBack] — on **both
///   platforms** (Android via the native `leadingNavigationIcon`, wrapped
///   native Android SDK 1.12.1+; iOS via `navBarLeadingAction`, 1.12.2+). This
///   replaces the host-owned close-bar workaround the scenario used before:
///   the iOS SDK only paints its own close button when presented natively
///   (`.sheet` / `.fullScreenCover`), which never happens for a Flutter-hosted
///   `UiKitView`, so previously the modal had no native dismissal affordance
///   on iOS, and the Android wrapper could only show a back arrow. Unlike a
///   `trailingWidget` overlay, the native button never reparents the embedded
///   `PlatformView` (no reparenting-induced sub-navigation drop) and the SDK hides it
///   automatically on deeper screens, where its own back chevron takes over.
///
/// An explicit `navBarLeadingAction` takes precedence over [showBackButton] on
/// both platforms, so the modal shows the Close (X) regardless. [showBackButton]
/// is left `true` as a harmless fallback (it would drive the icon only if
/// `navBarLeadingAction` were `null`); the Android system back gesture/button
/// pops the route too. The modal therefore has a native dismissal affordance
/// on both platforms with no host-owned chrome.
///
/// **Bottom inset.** The route hosts the SDK PlatformView edge-to-edge
/// (`SafeArea(bottom: false)`), so the host forwards the device's bottom
/// gesture-area inset via `bottomSafeAreaInset` — the SDK's floating
/// "Write a post" pill then clears the gesture pill (Android edge-to-edge,
/// API 35+) / home indicator (iOS). The *raw View's* `viewPadding` reports
/// the physical inset regardless of upstream SafeArea consumption — the
/// inherited `MediaQuery`'s does not (`MediaQueryData.removePadding` subtracts
/// `padding.bottom` from it).
///
/// **Login + profile-edit routing.** Both callbacks resolve `Navigator.of`
/// against the pushed route's `BuildContext`. Because the host wraps the
/// SDK in a regular route (not a nested [Navigator]), these pushes stack
/// the Flutter login / profile-edit screen *over* the modal; popping
/// returns to the modal with the freshly-connected session (the SDK
/// observes `OctopusSDK.profile` and re-renders automatically).
class ModalScenario extends StatelessWidget {
  const ModalScenario({super.key});

  @override
  Widget build(BuildContext context) {
    // Opens the SDK as a full-screen modal. [deepLink] true forces the bundled
    // sample notification so this presentation mode's deep-link can be verified
    // on its own (no live push needed — the live push path always routes to the
    // Community tab); false honours an active push deep link, else opens root.
    Future<void> open(
      ScenarioResultSink setResult, {
      bool deepLink = false,
    }) async {
      try {
        demoLog.apiCall('Navigator.push<OctopusHomeScreen>', {
          'fullscreenDialog': true,
          'navigationMode': 'navigationStack',
          'navBarLeadingAction': 'close',
          'deepLink': deepLink,
        });
        final app = AppScope.of(context);
        // Resolve the navigator before any await so we don't keep the outer
        // BuildContext across an async gap.
        final navigator = Navigator.of(context);
        // Forward the device's bottom gesture-area inset (raw View, immune to
        // what the widget tree consumes) so the SDK's floating "Write a post" pill
        // clears the gesture pill / home indicator. Captured before the await.
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
              ? 'Modal opened (deep-linked to sample post).'
              : 'Modal opened.',
        );
        unawaited(
          navigator.push(
            MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (routeContext) => Scaffold(
                body: SafeArea(
                  bottom: false,
                  child: OctopusHomeScreen(
                    theme: app.effectiveOctopusTheme(),
                    navBarTitle: 'Community',
                    navBarPrimaryColor: false,
                    showBackButton: true,
                    // 1.12.2: keep sub-navigation working in the modal (iOS) and
                    // show the native SDK close button (iOS).
                    navigationMode: OctopusNavigationMode.navigationStack,
                    navBarLeadingAction: OctopusNavBarLeadingAction.close,
                    bottomSafeAreaInset: bottomSafeArea,
                    // Deep-link target for this mode: the sample post for
                    // Preset 2, an active push deep link otherwise. Read at
                    // mount only (PlatformView creationParams) — fine, the route
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
                        'mode': 'modal',
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
        setResult('Modal scenario failed: $e', isError: true);
      }
    }

    return ScenarioScaffold(
      title: 'Modal',
      api: 'fullscreenDialog',
      description:
          'Open the SDK as a full-screen modal — '
          'MaterialPageRoute(fullscreenDialog: true) hosting '
          'OctopusHomeScreen, the Flutter equivalent of iOS .fullScreenCover. '
          'Slides up on iOS (no swipe-back-from-edge — modals are dismissed '
          'explicitly). Uses navigationMode: navigationStack so sub-navigation '
          'works in the modal on iOS, and navBarLeadingAction: close for the '
          'native SDK close button (X) that fires onBack. Preset 2 opens it '
          'deep-linked to the sample post so this mode can be QA-verified '
          'without a live push.',
      resultTestId: 'modal-result',
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-modal-1',
          label: 'Preset 1 · Open SDK as full-screen modal',
          onRun: (setResult) => open(setResult),
        ),
        ScenarioPreset(
          testId: 'qa-preset-modal-2',
          label: 'Preset 2 · Open deep-linked to sample post',
          onRun: (setResult) => open(setResult, deepLink: true),
        ),
      ],
    );
  }
}
