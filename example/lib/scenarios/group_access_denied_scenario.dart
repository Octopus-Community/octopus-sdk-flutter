import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_scaffold.dart';

/// Group access denied scenario — `setGroupAccessDeniedCallback`.
///
/// Registers a global callback fired by the SDK when the connected user
/// attempts to interact with a group they do not have access to (taps a
/// visible-but-locked group, its follow button, or a locked detail CTA).
/// The SDK never navigates on the user's behalf — the host decides what to
/// do (open an upsell, a paywall, etc.).
///
/// Stateful so the registration handle survives across rebuilds and is
/// properly released in [dispose] (matching the recommended host pattern).
class GroupAccessDeniedScenario extends StatefulWidget {
  const GroupAccessDeniedScenario({super.key});

  @override
  State<GroupAccessDeniedScenario> createState() =>
      _GroupAccessDeniedScenarioState();
}

class _GroupAccessDeniedScenarioState extends State<GroupAccessDeniedScenario> {
  /// Cancellation handle returned by [OctopusSDK.setGroupAccessDeniedCallback].
  /// `null` means the callback is not currently registered from this scenario.
  VoidCallback? _cancel;

  /// Last `groupId` the callback fired with, or `null` if it never fired.
  String? _lastGroupId;

  /// How many times the callback has fired since it was registered.
  int _fireCount = 0;

  @override
  void initState() {
    super.initState();
    _register();
  }

  @override
  void dispose() {
    _cancel?.call();
    _cancel = null;
    super.dispose();
  }

  /// Registers (or re-arms) the SDK callback. No-op if already armed from this
  /// scenario — the SDK itself is last-write-wins, so re-registering with the
  /// same closure would still work, but skipping avoids surprising the host.
  void _register() {
    if (_cancel != null) return;
    demoLog.apiCall('setGroupAccessDeniedCallback');
    _cancel = OctopusSDK.setGroupAccessDeniedCallback((groupId) {
      if (!mounted) return;
      setState(() {
        _lastGroupId = groupId;
        _fireCount += 1;
      });
    });
  }

  /// Unregisters the SDK callback if currently armed from this scenario.
  void _unregister() {
    _cancel?.call();
    _cancel = null;
  }

  @override
  Widget build(BuildContext context) {
    final registered = _cancel != null;
    return ScenarioScaffold(
      title: 'Group access denied',
      api: 'setGroupAccessDeniedCallback',
      description:
          'Register a callback fired when the user taps a locked group, its '
          'follow button, or a locked detail CTA. The SDK never navigates on '
          'the user\'s behalf — the host decides (upsell, paywall, …). The '
          'callback is registered automatically when this screen opens and is '
          'released in dispose; the presets below let QA re-arm or unregister '
          'it explicitly.',
      resultTestId: 'groupAccessDenied-result',
      liveState: KeyValueCard(
        title: 'Live state',
        rows: [
          ('Registration', registered ? 'registered' : 'unregistered'),
          ('Last groupId', _lastGroupId ?? '—'),
          ('Fire count', _fireCount.toString()),
        ],
      ),
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-groupAccessDenied-1',
          label: 'Preset 1 · Register callback',
          onRun: (setResult) async {
            try {
              final wasRegistered = _cancel != null;
              _register();
              if (!mounted) return;
              setState(() {});
              setResult(
                wasRegistered
                    ? 'Callback already registered — no-op (still armed).'
                    : 'Callback registered. It will fire when the user taps a '
                          'locked group in the Community tab.',
              );
            } catch (e) {
              setResult(
                'setGroupAccessDeniedCallback failed: $e',
                isError: true,
              );
            }
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-groupAccessDenied-2',
          label: 'Preset 2 · Unregister callback',
          onRun: (setResult) async {
            try {
              final wasRegistered = _cancel != null;
              demoLog.apiCall('setGroupAccessDeniedCallback.cancel');
              _unregister();
              if (!mounted) return;
              setState(() {});
              setResult(
                wasRegistered
                    ? 'Callback unregistered. The SDK will no longer notify '
                          'this scenario when a locked group is tapped.'
                    : 'Callback was already unregistered — no-op.',
              );
            } catch (e) {
              setResult('Unregister failed: $e', isError: true);
            }
          },
        ),
      ],
    );
  }
}
