import 'dart:async';

import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../auth/login_page.dart';
import '../auth/profile_edit_page.dart';
import '../widgets/scenario_scaffold.dart';

/// Track A/B Tests scenario — mirrors iOS `TrackABTests`.
///
/// Shows the cross-platform pattern for hosts that run their own A/B tests to
/// gate community access: toggle a per-cohort "can access" flag, inform the SDK
/// via [OctopusSDK.trackCommunityAccess] every time the cohort changes, and
/// only open the embedded community when the user is in the access-granted
/// cohort. The toggle stands in for an actual A/B-test decision the host would
/// take from its own analytics / feature-flag service.
///
/// Driven by a single live-state Switch (canAccessCommunity, default ON), with
/// a preset that pushes [OctopusHomeScreen] full-page. The preset is
/// always-tappable but reports an error when the toggle is OFF — the
/// functional equivalent of the iOS sample's disabled button (Flutter's
/// preset pattern is one-tap-always, errors guard the cohort condition).
class TrackABTestsScenario extends StatefulWidget {
  const TrackABTestsScenario({super.key});

  @override
  State<TrackABTestsScenario> createState() => _TrackABTestsScenarioState();
}

class _TrackABTestsScenarioState extends State<TrackABTestsScenario> {
  /// Stands in for the host's A/B-test cohort decision (default ON, matching
  /// iOS' "user starts in the access-granted cohort"). Every change is fired
  /// at the SDK via [OctopusSDK.trackCommunityAccess] so the cohort
  /// attribution feeds Octopus analytics.
  bool _canAccessCommunity = true;

  Future<void> _onToggle(bool value) async {
    setState(() => _canAccessCommunity = value);
    final app = AppScope.of(context);
    demoLog.apiCall('trackCommunityAccess', {'hasAccess': value});
    // Fire-and-forget — bridge call returns Future<void>, errors at this
    // layer are surfaced via the SDK's own logging.
    try {
      await app.octopus.trackCommunityAccess(value);
    } catch (_) {
      /* best-effort */
    }
  }

  Future<void> _openOctopus(ScenarioResultSink setResult) async {
    if (!_canAccessCommunity) {
      setResult(
        'Toggle "Can access the community" is OFF — flip it on to simulate '
        'the access-granted cohort before opening Octopus. (Mirrors the iOS '
        'sample\'s disabled "Open Octopus Home Screen" button when the '
        'cohort is OFF — host hides the community UI from out-of-cohort '
        'users.)',
        isError: true,
      );
      return;
    }
    final app = AppScope.of(context);
    final navigator = Navigator.of(context);
    demoLog.apiCall('Navigator.push(OctopusHomeScreen)');
    setResult('Opening Octopus Home Screen (access-granted cohort).');
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          // Wrap in `Scaffold` + `SafeArea(bottom: false)` — the same shape
          // `OctopusSDK.showOctopusHomeScreen` uses. The `Scaffold` paints a
          // surface behind the status-bar inset; `SafeArea(bottom: false)`
          // offsets the SDK's native top bar below the status bar and leaves
          // the gesture-area inset to the SDK.
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
    return ScenarioScaffold(
      title: 'Track A/B Tests',
      description:
          'When the host runs its own A/B test to enable/disable community '
          'access, call OctopusSDK.trackCommunityAccess(bool) every time the '
          'cohort changes so Octopus analytics reflect which users were '
          'eligible. The toggle below simulates a host A/B decision: ON = '
          'show the community UI; OFF = host hides the community (the '
          'embedded UI should not be opened).',
      resultTestId: 'trackABTests-result',
      liveState: _CanAccessSwitch(
        value: _canAccessCommunity,
        onChanged: _onToggle,
      ),
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-trackABTests-1',
          label: 'Preset 1 · Open Octopus Home Screen',
          onRun: _openOctopus,
        ),
      ],
    );
  }
}

/// Live-state Switch standing in for the host's per-user A/B cohort decision.
/// QA reads it via the `qa-trackABTests-can-access-switch` Semantics id.
class _CanAccessSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CanAccessSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Can access the community',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Simulates the host\'s A/B-test decision. Toggling fires '
                    'OctopusSDK.trackCommunityAccess(value).',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            MergeSemantics(
              child: Semantics(
                identifier: 'qa-trackABTests-can-access-switch',
                toggled: value,
                child: Switch(value: value, onChanged: onChanged),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
