import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../auth/login_page.dart';
import '../auth/profile_edit_page.dart';
import '../octopus_demo_config.dart';
import '../widgets/scenario_scaffold.dart';

/// Sheet scenario — host integration mode where the SDK's
/// [OctopusHomeScreen] is presented inside a Material
/// [showModalBottomSheet] sized to 90% of the viewport. Flutter equivalent
/// of iOS sample's `SheetCell` which presents the SDK in a non-fullscreen
/// SwiftUI sheet.
///
/// One of the three presentation shapes the sample demos side by side:
/// **Modal** (`fullscreenDialog` route, slide-up on iOS, X close
/// affordance), **Fullscreen** (standard `MaterialPageRoute` push), and
/// **Sheet** (this scenario).
///
/// Demonstrates that the embedded [OctopusHomeScreen] widget can be hosted
/// inside any standard Flutter presentation primitive — here a draggable
/// bottom sheet rather than a full-page route. The sheet closes via:
/// - **Both platforms**: a native close (X) leading action on the SDK's root
///   nav-bar (`navBarLeadingAction: OctopusNavBarLeadingAction.close`) — Android
///   via the native `leadingNavigationIcon` (wrapped native SDK 1.12.1+), iOS
///   via `navBarLeadingAction` (1.12.2+). Tapping it fires `onBack`.
/// - Either platform: dragging the Material drag handle (rendered above the
///   embedded view via `showDragHandle: true`). On both platforms the embedded
///   view eagerly claims body pointers (so the SDK feed scrolls inside the
///   sheet), so dragging the body scrolls the feed rather than dismissing —
///   the handle (or the X) is the dismiss gesture.
///
/// **Modal sub-navigation (iOS).** A bottom sheet is a modal presentation,
/// so this scenario sets [OctopusHomeScreen.navigationMode] to
/// [OctopusNavigationMode.navigationStack] (wrapped iOS SDK 1.12.2+): iOS
/// reparents the SDK's hosting controller during the sheet presentation, and
/// the default legacy `NavigationView` can silently drop sub-navigation
/// pushes there (a post tap not opening its detail) — `navigationStack` keeps
/// them working. No-op on Android (the Compose `NavHost` keeps its back stack
/// across modal hosting already).
///
/// **History note (1.12.0).** During development, mounting the SDK in a
/// `showModalBottomSheet` was reported to silently drop SDK sub-navigation
/// (post taps registering a view without pushing detail). Two distinct
/// mechanisms were behind that: the Flutter overlay gating reparenting the
/// `PlatformView` when a `leadingWidget`/`trailingWidget` was configured
/// (fixed in `octopus_home_screen.dart` — the tree shape is now stable), and,
/// on iOS, the legacy `NavigationView` dropping pushes under modal hosting
/// (now addressed by `navigationMode: navigationStack`, above). The bottom
/// sheet primitive itself was never at fault. History tracked internally.
///
/// **Login + profile-edit routing.** Both callbacks resolve `Navigator.of`
/// against the modal's `BuildContext` with `rootNavigator: true`, which
/// walks up past the modal route to the root `Navigator`. Pushing a
/// `MaterialPageRoute` from there stacks the Flutter login / profile-edit
/// screen *over* the sheet; popping returns to the sheet with the
/// freshly-connected session (the SDK observes `OctopusSDK.profile` and
/// re-renders automatically). Same path as the embedded Community tab and
/// the Modal / Fullscreen scenarios.
class SheetScenario extends StatelessWidget {
  const SheetScenario({super.key});

  @override
  Widget build(BuildContext context) {
    // Opens the SDK in a 90%-height modal bottom sheet. [deepLink] true forces
    // the bundled sample notification so this presentation mode's deep-link can
    // be verified on its own (no live push needed — the live push path always
    // routes to the Community tab); false honours an active push deep link.
    Future<void> open(
      ScenarioResultSink setResult, {
      bool deepLink = false,
    }) async {
      try {
        demoLog.apiCall('showModalBottomSheet<OctopusHomeScreen>', {
          'deepLink': deepLink,
        });
        final app = AppScope.of(context);
        // Forward the device's bottom inset (raw View, immune to what the widget
        // tree consumes) so the floating "Write a post" pill stays above the
        // home indicator. Captured before the await.
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
              ? 'Sheet opened (deep-linked to sample post).'
              : 'Sheet opened.',
        );
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (modalContext) {
            // Keep the SDK's bottom input bar (comment composer / post editor)
            // above the software keyboard. The sheet is a fixed fraction of the
            // screen and showModalBottomSheet does not resize for the IME, so
            // without this the sheet's bottom — where the native input sits —
            // slides behind the keyboard (masking it on both platforms). Lift
            // the content by the keyboard inset and cap its height to the space
            // that remains above the keyboard. Collapses to the plain 90% sheet
            // when the keyboard is closed (`viewInsets.bottom == 0`).
            final mediaQuery = MediaQuery.of(modalContext);
            final keyboardInset = mediaQuery.viewInsets.bottom;
            final fullHeight = mediaQuery.size.height;
            final maxHeight = fullHeight * 0.9;
            final available = fullHeight - keyboardInset;
            return Padding(
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: SizedBox(
                height: maxHeight < available ? maxHeight : available,
                child: OctopusHomeScreen(
                  theme: app.effectiveOctopusTheme(),
                  // A bottom sheet is a modal presentation: keep the SDK's
                  // sub-navigation working on iOS (no-op on Android).
                  navigationMode: OctopusNavigationMode.navigationStack,
                  // Render a native close (X) leading action on the SDK's root
                  // screen so the modal sheet has an obvious dismiss affordance
                  // in addition to the M3 drag handle above the AndroidView.
                  // The tap is routed through `backRequested` → onBack. On both
                  // platforms the embedded view eagerly claims body pointers (the
                  // SDK feed scrolls inside the sheet), so dragging the body
                  // scrolls rather than dismisses — the close affordance is the
                  // X / drag handle.
                  //
                  // Cross-platform parity: the native close (X) now renders on
                  // BOTH platforms. The Android native `OctopusHomeScreen` public
                  // composable gained a `leadingNavigationIcon: NavigationIconType?`
                  // (wrapped native SDK 1.12.1+) — the Flutter wrapper maps
                  // `OctopusNavBarLeadingAction.close` to `NavigationIconType.Close`
                  // (closing the former Android public-API gap, tracked
                  // internally). It takes precedence over the default
                  // `showBackButton`, so the X shows instead of a chevron.
                  navBarLeadingAction: OctopusNavBarLeadingAction.close,
                  bottomSafeAreaInset: bottomSafeArea,
                  // Deep-link target for this mode: the sample post for Preset 2,
                  // an active push deep link otherwise. Read at mount only
                  // (PlatformView creationParams) — fine, the sheet is freshly
                  // built each time.
                  notification: notification,
                  onBack: () => Navigator.of(modalContext).pop(),
                  onNavigateToLogin: () => Navigator.of(
                    modalContext,
                    rootNavigator: true,
                  ).push(MaterialPageRoute(builder: (_) => const LoginPage())),
                  onModifyUser: (field) =>
                      Navigator.of(modalContext, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileEditPage(fieldToEdit: field),
                        ),
                      ),
                ),
              ),
            );
          },
        );
        setResult('Sheet closed.');
      } catch (e) {
        setResult('Sheet scenario failed: $e', isError: true);
      }
    }

    return ScenarioScaffold(
      title: 'Sheet',
      description:
          'Open the SDK as a modal bottom sheet — host integration mode where '
          'OctopusHomeScreen is presented inside a showModalBottomSheet sized '
          'to 90% of the viewport (Flutter equivalent of iOS non-fullscreen '
          'sheet). The sheet closes via the SDK leading action — a native '
          'close (X) icon shown on both platforms (Android via the native '
          'leadingNavigationIcon, wrapped native SDK 1.12.1+; iOS via '
          'navBarLeadingAction) — or by dragging '
          'the Material drag handle above the embedded view. On both platforms '
          'the embedded view consumes body drags to scroll the SDK feed, so '
          'dragging the body scrolls rather than dismisses — use the handle or '
          'the X. Preset 2 opens it deep-'
          'linked to the sample post so this mode can be QA-verified without '
          'a live push.',
      resultTestId: 'sheet-result',
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-sheet-1',
          label: 'Preset 1 · Open SDK as bottom sheet',
          onRun: (setResult) => open(setResult),
        ),
        ScenarioPreset(
          testId: 'qa-preset-sheet-2',
          label: 'Preset 2 · Open deep-linked to sample post',
          onRun: (setResult) => open(setResult, deepLink: true),
        ),
      ],
    );
  }
}
