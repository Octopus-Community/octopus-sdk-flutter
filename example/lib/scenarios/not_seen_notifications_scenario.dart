import 'dart:async';

import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../auth/login_page.dart';
import '../auth/profile_edit_page.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_scaffold.dart';

/// Not-seen notifications scenario — reads `OctopusSDK.notSeenNotificationsCount`
/// (a reactive stream surfaced through [AppState.notSeenCount]) and forces a
/// server refresh via `updateNotSeenNotificationsCount()`.
///
/// Mirrors the iOS sample's `NotSeenNotificationsView`: the badge / current
/// value is read directly from the stream; the host exposes a CTA that opens
/// the Octopus community as a full-page route (badged with the live count),
/// and a preset that forces a refresh.
class NotSeenNotificationsScenario extends StatefulWidget {
  const NotSeenNotificationsScenario({super.key});

  @override
  State<NotSeenNotificationsScenario> createState() =>
      _NotSeenNotificationsScenarioState();
}

class _NotSeenNotificationsScenarioState
    extends State<NotSeenNotificationsScenario> {
  @override
  void initState() {
    super.initState();
    // Mirrors iOS `.onAppear` (NotSeenNotificationsView.swift line 71):
    // force a server refresh as soon as the scenario is displayed so the
    // badge reflects the latest server-side count without waiting for a
    // manual tap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = AppScope.of(context);
      // Skip the auto-refresh until the SDK is initialised: calling
      // updateNotSeenNotificationsCount() before init makes the native
      // handler reject with a PlatformException, and a fire-and-forget
      // call would then surface as an unhandled async-zone error. The
      // iOS `.onAppear` equivalent swallows the same case via `try?`.
      if (!app.isInitialised) return;
      // Fire-and-forget: any error is surfaced through the "Refresh count"
      // preset; here we just swallow so initState never throws or holds
      // the frame.
      unawaited(
        app.octopus.updateNotSeenNotificationsCount().catchError((_) {}),
      );
    });
  }

  void _openOctopus(BuildContext context) {
    final app = AppScope.of(context);
    final navigator = Navigator.of(context);
    demoLog.apiCall('Navigator.push(OctopusHomeScreen)');
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          // Wrap in `Scaffold` + `SafeArea(bottom: false)` — the same shape
          // `OctopusSDK.showOctopusHomeScreen` uses. The `Scaffold` paints a
          // surface behind the status-bar inset (without it the unpainted top
          // area shows the route's black backdrop); `SafeArea(bottom: false)`
          // offsets the SDK's native top bar below the status bar — on Android
          // the PlatformView consumes the system-bar insets, assuming the host
          // owns them — while leaving the gesture-area inset to the SDK.
          builder: (routeContext) => Scaffold(
            body: SafeArea(
              bottom: false,
              child: OctopusHomeScreen(
                theme: app.effectiveOctopusTheme(),
                showBackButton: true,
                onBack: () => Navigator.of(routeContext).pop(),
                onNavigateToLogin: () => Navigator.of(
                  routeContext,
                ).push(MaterialPageRoute(builder: (_) => const LoginPage())),
                onModifyUser: (field) => Navigator.of(routeContext).push(
                  MaterialPageRoute(
                    builder: (_) => ProfileEditPage(fieldToEdit: field),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final count = app.notSeenCount ?? 0;
    return ScenarioScaffold(
      title: 'Not-Seen Notifications',
      description:
          'Demonstrates the `notSeenNotificationsCount` stream. The badge on '
          'the "Open Octopus" button updates reactively as the SDK pushes new '
          'counts. The scenario auto-refreshes the count on entry and exposes '
          'a preset to force another refresh.',
      resultTestId: 'notSeenNotifications-result',
      liveState: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyValueCard(
            title: 'Live state',
            rows: [
              (
                'notSeenNotificationsCount',
                app.notSeenCount?.toString() ?? '—',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Badged CTA — mirrors the iOS button at line 36-61 of
          // NotSeenNotificationsView.swift. Tapping it is equivalent to
          // Preset 1 (push the SDK as a full-page route).
          MergeSemantics(
            child: Semantics(
              identifier: 'qa-open-octopus-badge',
              button: true,
              child: Badge.count(
                count: count,
                isLabelVisible: count > 0,
                child: OutlinedButton.icon(
                  onPressed: () => _openOctopus(context),
                  icon: const Icon(Icons.open_in_full),
                  label: const Text('Open Octopus'),
                ),
              ),
            ),
          ),
        ],
      ),
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-notSeenNotifications-1',
          label: 'Preset 1 · Open Octopus (full-page route)',
          onRun: (setResult) async {
            try {
              if (!mounted) return;
              _openOctopus(context);
              setResult('Pushed full-page Octopus route.');
            } catch (e) {
              setResult('Failed to push full-page route: $e', isError: true);
            }
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-notSeenNotifications-2',
          label: 'Preset 2 · Refresh not-seen count',
          onRun: (setResult) async {
            try {
              demoLog.apiCall('updateNotSeenNotificationsCount');
              await app.octopus.updateNotSeenNotificationsCount();
              if (!mounted) return;
              setResult(
                'Refresh requested. Latest notSeenNotificationsCount: '
                '${app.notSeenCount?.toString() ?? '—'}.',
              );
            } catch (e) {
              if (!mounted) return;
              setResult(
                'updateNotSeenNotificationsCount failed: $e',
                isError: true,
              );
            }
          },
        ),
      ],
    );
  }
}
