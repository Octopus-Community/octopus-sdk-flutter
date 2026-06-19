import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_scaffold.dart';

/// Renders an [OctopusResult] from `overrideCommunityAccess` into a result
/// string, pattern-matching the typed [OverrideCommunityAccessError] subtypes
/// so the QA Tester sees which branch fired.
String _describeOverrideResult(
  bool hasAccess,
  OctopusResult<void, OverrideCommunityAccessError> result,
) {
  switch (result) {
    case OctopusSuccess():
      return 'forceOctopusABTest(hasAccess=$hasAccess) → success. '
          'The cohort attribution has been overridden for the current user.';
    case OctopusInvalidArguments<OctopusServerError>(:final errors):
      // Narrow back to the method's typed error to enumerate known leaves.
      final labels = errors
          .cast<OverrideCommunityAccessError>()
          .map((error) {
            final label = switch (error) {
              OverrideCommunityAccessUnknownError() => 'Unknown',
            };
            return 'OverrideCommunityAccess$label: $error';
          })
          .join(', ');
      return 'forceOctopusABTest(hasAccess=$hasAccess) → failed with $labels.';
    case OctopusConnectionFailure():
      return 'forceOctopusABTest(hasAccess=$hasAccess) → '
          'connection-layer failure: $result';
  }
}

/// Force Octopus A/B Tests scenario — mirrors iOS `ForceOctopusABTests`.
///
/// Some communities use Octopus-internal A/B Tests to gate community access.
/// The `overrideCommunityAccess` API lets the host force the current user's
/// cohort attribution (permanently overriding the SDK's internal decision)
/// instead of merely reporting it via `trackCommunityAccess`.
///
/// Live state surfaces the SDK's current `hasAccessToCommunity` value so the
/// effect of each override is visible immediately after a preset runs.
class ForceOctopusABTestsScenario extends StatelessWidget {
  const ForceOctopusABTestsScenario({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ScenarioScaffold(
      title: 'Force Octopus A/B Tests',
      description:
          'On some communities, Octopus runs internal A/B Tests to decide '
          'whether a user can access the community. This scenario uses '
          'overrideCommunityAccess to force the cohort attribution for the '
          'current user (granted or denied). The change is permanent and '
          'reflected in the hasAccessToCommunity stream below.',
      resultTestId: 'force-octopus-ab-tests-result',
      liveState: KeyValueCard(
        title: 'Live state',
        rows: [('hasAccessToCommunity', app.hasAccess?.toString() ?? '—')],
      ),
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-force-octopus-ab-tests-1',
          label: 'Preset 1 · Force cohort · grant community access',
          onRun: (setResult) async {
            try {
              demoLog.apiCall('overrideCommunityAccess', {'hasAccess': true});
              final result = await app.octopus.overrideCommunityAccess(true);
              setResult(
                _describeOverrideResult(true, result),
                isError: result.isFailure,
              );
            } catch (e) {
              setResult(
                'overrideCommunityAccess(true) threw: $e',
                isError: true,
              );
            }
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-force-octopus-ab-tests-2',
          label: 'Preset 2 · Force cohort · deny community access',
          onRun: (setResult) async {
            try {
              demoLog.apiCall('overrideCommunityAccess', {'hasAccess': false});
              final result = await app.octopus.overrideCommunityAccess(false);
              setResult(
                _describeOverrideResult(false, result),
                isError: result.isFailure,
              );
            } catch (e) {
              setResult(
                'overrideCommunityAccess(false) threw: $e',
                isError: true,
              );
            }
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-force-octopus-ab-tests-3',
          label: 'Preset 3 · Re-apply current SDK value',
          onRun: (setResult) async {
            try {
              final current = app.hasAccess;
              if (current == null) {
                setResult(
                  'hasAccessToCommunity is not yet known — initialize the SDK '
                  'first, then retry this preset.',
                  isError: true,
                );
                return;
              }
              demoLog.apiCall('overrideCommunityAccess', {
                'hasAccess': current,
              });
              final result = await app.octopus.overrideCommunityAccess(current);
              setResult(
                _describeOverrideResult(current, result),
                isError: result.isFailure,
              );
            } catch (e) {
              setResult(
                'overrideCommunityAccess (re-apply) threw: $e',
                isError: true,
              );
            }
          },
        ),
      ],
    );
  }
}
