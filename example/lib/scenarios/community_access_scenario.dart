import 'package:flutter/material.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_scaffold.dart';

/// Combined community-access demo: overrideCommunityAccess is enforced by the
/// SDK; trackCommunityAccess is analytics-only. There is no reset call for the
/// override — reapply the other preset to reverse it.
class CommunityAccessScenario extends StatelessWidget {
  const CommunityAccessScenario({super.key});

  Future<void> _override(
    AppState app,
    bool hasAccess,
    ScenarioResultSink setResult,
  ) async {
    try {
      demoLog.apiCall('overrideCommunityAccess', {'hasAccess': hasAccess});
      final result = await app.octopus.overrideCommunityAccess(hasAccess);
      setResult(
        'overrideCommunityAccess($hasAccess) → $result',
        isError: result.isFailure,
      );
    } catch (e) {
      setResult(
        'overrideCommunityAccess($hasAccess) failed: $e',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ScenarioScaffold(
      title: 'Community Access',
      api: 'overrideCommunityAccess',
      description:
          'Grant or deny community access with an SDK-enforced override, or '
          'report access for analytics only. Tracking does not change access.',
      note:
          'There is no reset call for the override. Reapply the other '
          'override preset to reverse it.',
      resultTestId: 'communityAccess-result',
      liveState: KeyValueCard(
        title: 'Live state',
        rows: [('hasAccessToCommunity', app.hasAccess?.toString() ?? '—')],
      ),
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-communityAccess-1',
          label: 'Override · grant access',
          onRun: (setResult) => _override(app, true, setResult),
        ),
        ScenarioPreset(
          testId: 'qa-preset-communityAccess-2',
          label: 'Override · deny access',
          onRun: (setResult) => _override(app, false, setResult),
        ),
        ScenarioPreset(
          testId: 'qa-preset-communityAccess-3',
          label: 'Track · has access',
          onRun: (setResult) async {
            try {
              demoLog.apiCall('trackCommunityAccess', {'hasAccess': true});
              await app.octopus.trackCommunityAccess(true);
              setResult(
                'trackCommunityAccess(true) → reported for analytics only.',
              );
            } catch (e) {
              setResult('trackCommunityAccess(true) failed: $e', isError: true);
            }
          },
        ),
      ],
    );
  }
}
