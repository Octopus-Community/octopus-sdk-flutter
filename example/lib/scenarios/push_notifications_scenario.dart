import 'dart:async';

import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../auth/login_page.dart';
import '../auth/profile_edit_page.dart';
import '../octopus_demo_config.dart';
import '../widgets/scenario_scaffold.dart';

/// Push-notifications scenario — replays the full push-tap path
/// `isOctopusNotification` → `getOctopusNotification` → `openNotification` from
/// a bundled sample payload, without needing an actual FCM/APNs push (which a
/// simulator/emulator cannot easily deliver).
///
/// The payload comes from [sampleOctopusNotificationPayload] and matches the
/// shape `RemoteMessage.data` (Android FCM) / `userInfo` (iOS APNs) delivers.
class PushNotificationsScenario extends StatefulWidget {
  const PushNotificationsScenario({super.key});

  @override
  State<PushNotificationsScenario> createState() =>
      _PushNotificationsScenarioState();
}

class _PushNotificationsScenarioState extends State<PushNotificationsScenario> {
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ScenarioScaffold(
      title: 'Push Notifications',
      api: 'isOctopusNotification / openNotification',
      description:
          'Replays the full push-tap path from a bundled sample payload — '
          'isOctopusNotification → getOctopusNotification → openNotification — '
          'without an actual push.',
      resultTestId: 'pushNotifications-result',
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-pushNotifications-1',
          label: 'Preset 1 · Open sample notification (deep link)',
          onRun: (setResult) async {
            if (!mounted) return;
            // Gate on the host-side init flag (set when `octopus.initialize()`
            // resolved), not the event-driven `isInitialised`: the latter can
            // stay false after an Android cold start when a secondary FCM
            // FlutterEngine overwrites the static event emitter and drops the
            // `isInitialisedChanged` burst.
            if (!app.initialized) {
              setResult(
                'SDK not initialised yet — start it from the Config screen '
                'first, then retry.',
                isError: true,
              );
              return;
            }
            // Parse the bundled fixture through the exact host code path a
            // real FCM/APNs tap would take (see main.dart _handleNotification).
            final payload = sampleOctopusNotificationPayload;
            if (!OctopusSDK.isOctopusNotification(payload)) {
              setResult(
                'Sample payload not recognised as an Octopus notification.',
                isError: true,
              );
              return;
            }
            final notification = OctopusSDK.getOctopusNotification(payload);
            if (notification == null) {
              setResult(
                'Failed to parse the sample notification payload.',
                isError: true,
              );
              return;
            }
            try {
              demoLog.apiCall('openNotification', {
                'linkPath': notification.linkPath,
                'postId': notification.postId,
              });
              final target = hasDemoPostId
                  ? 'real post ${notification.postId}'
                  : 'a not-found placeholder post (OCTOPUS_DEMO_POST_ID set '
                        'empty — the SDK handles the stale link gracefully)';
              setResult(
                'Opening Octopus via openNotification(linkPath='
                '"${notification.linkPath}") → deep-links to $target.',
              );
              // Fire-and-forget so the preset button doesn't stay "running"
              // for the whole time the SDK route is on screen — mirrors the
              // "Open Octopus" launcher in the not-seen-notifications scenario.
              unawaited(
                app.octopus.openNotification(
                  context,
                  notification,
                  theme: app.effectiveOctopusTheme(),
                  onNavigateToLogin: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const LoginPage())),
                  onModifyUser: (field) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfileEditPage(fieldToEdit: field),
                    ),
                  ),
                ),
              );
            } catch (e) {
              if (!mounted) return;
              setResult('openNotification failed: $e', isError: true);
            }
          },
        ),
      ],
    );
  }
}
