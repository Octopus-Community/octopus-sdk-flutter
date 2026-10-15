import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;

import '../app_log.dart';
import '../app_state.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_scaffold.dart';

const String _noOverrideLabel = 'none (backend default)';

/// Debug nickname choice presets shared with the native samples.
class ForceNicknameChoiceScenario extends StatefulWidget {
  const ForceNicknameChoiceScenario({super.key});

  @override
  State<ForceNicknameChoiceScenario> createState() =>
      _ForceNicknameChoiceScenarioState();
}

class _ForceNicknameChoiceScenarioState
    extends State<ForceNicknameChoiceScenario> {
  /// Applies [enabled] (or clears the override when `null`) and reports it.
  ///
  /// [label] is the preset's own wording rather than the enum's `toString()` —
  /// `forceNicknameChoice-result` is a catalog `result_test_id`, so what it renders
  /// is worth keeping deliberate and readable. Iso the Android sample's sibling
  /// override sections, the line always starts with `Applied: `.
  Future<void> _apply(
    ScenarioResultSink setResult,
    String label,
    bool? enabled,
  ) async {
    final app = AppScope.of(context);
    final overrides = app.debugScenarioOverrides;
    demoLog.apiCall('debugOverrideForceNicknameChoice', {
      'enabled': enabled?.toString() ?? 'null (clear)',
    });
    try {
      await app.applyForceNicknameChoice(enabled, label);
      if (!identical(overrides, app.debugScenarioOverrides)) return;
      if (!mounted) return;
      setState(() {});
      setResult(
        enabled == null
            ? 'Applied: $_noOverrideLabel. The community config served by the '
                  'backend applies again.'
            : 'Applied: $label. Open the Community tab and make a first '
                  'contribution with a member whose nickname is not confirmed.',
      );
    } on PlatformException catch (e) {
      if (!identical(overrides, app.debugScenarioOverrides)) return;
      setResult(
        e.code == 'UNSUPPORTED_PLATFORM'
            ? 'debugOverrideForceNicknameChoice is unavailable on this build: '
                  '${e.message ?? e.code}'
            : 'debugOverrideForceNicknameChoice failed (${e.code}): '
                  '${e.message ?? 'no message'}',
        isError: true,
      );
    } catch (e) {
      if (!identical(overrides, app.debugScenarioOverrides)) return;
      setResult('debugOverrideForceNicknameChoice threw: $e', isError: true);
    }
  }

  /// One catalog preset. [label] carries the `Preset N · ` prefix the catalog
  /// uses on screen; [shortLabel] is what the result line reports.
  ScenarioPreset _preset({
    required String testId,
    required String label,
    required String shortLabel,
    required bool? enabled,
  }) => ScenarioPreset(
    testId: testId,
    label: label,
    onRun: (setResult) => _apply(setResult, shortLabel, enabled),
  );

  @override
  Widget build(BuildContext context) {
    final overrides = AppScope.of(context).debugScenarioOverrides;
    return ScenarioScaffold(
      key: ObjectKey(overrides),
      title: 'Force Nickname Choice',
      api: 'debugOverrideForceNicknameChoice',
      verifyInCommunity: true,
      description:
          'Choose whether the first nickname field starts empty or with the generated nickname.',
      youWillSee:
          'an empty nickname field when On, or the generated nickname when Off.',
      note:
          'Use an editable, unconfirmed nickname: apply Profile Fields Lock preset 1, then use a fresh guest or an SSO member whose nickname is not host-managed. A confirmed, locked or host-managed SSO nickname skips the screen; guests retain the flow. Relaunch, switch community or stop to discard the local override.',
      resultTestId: 'forceNicknameChoice-result',
      liveState: KeyValueCard(
        title: 'Live state',
        rows: [
          (
            'Applied override',
            overrides.forceNicknameChoice?.label ?? _noOverrideLabel,
          ),
          (
            'forceNicknameChoice',
            overrides.forceNicknameChoice?.value.toString() ?? '— (backend)',
          ),
        ],
      ),
      presets: [
        _preset(
          testId: 'qa-preset-forceNicknameChoice-1',
          label: 'On — the member types a nickname',
          shortLabel: 'On — the member types a nickname',
          enabled: true,
        ),
        _preset(
          testId: 'qa-preset-forceNicknameChoice-2',
          label: 'Off — the generated nickname is prefilled',
          shortLabel: 'Off — the generated nickname is prefilled',
          enabled: false,
        ),
        _preset(
          testId: 'qa-preset-forceNicknameChoice-clear',
          label: 'Clear override (backend default)',
          shortLabel: _noOverrideLabel,
          enabled: null,
        ),
      ],
    );
  }
}
