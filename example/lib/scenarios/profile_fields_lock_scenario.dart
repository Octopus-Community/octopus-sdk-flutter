import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_scaffold.dart';

/// The per-field lock currently overridden on the SDK, and the label of the
/// preset that applied it — `null` / "none (backend default)" when no override
/// is in effect.
///
/// Process-level rather than [State] fields, iso the Android sample's
/// `HostOverrides`: "Verify in Community" pops back to the shell and destroys
/// this scenario's State, so a per-widget field would render "none" on the way
/// back while the SDK is still overridden. Same reasoning as the `_expanded`
/// map of `scenarios_screen.dart`.
ProfileFieldsLock? _applied;
String _appliedLabel = _noOverrideLabel;

const String _noOverrideLabel = 'none (backend default)';

/// Profile Field Lock scenario — `debugOverrideProfileFieldsLock`.
///
/// Debug-only affordance (native `@InternalOctopusApi` /
/// `@_spi(OctopusInternalTesting)`, **not** supported public API) that
/// overrides the community's per-field profile lock locally, without a
/// backend-driven config. Each preset maps to one of the PRD combinations;
/// open your profile afterwards to observe the effect on the profile and edit
/// screens.
///
/// Preset ids and labels are the shared QA scenario catalog's, verbatim,
/// so the QA pipeline drives Android, iOS and Flutter with the same ids.
class ProfileFieldsLockScenario extends StatefulWidget {
  const ProfileFieldsLockScenario({super.key});

  @override
  State<ProfileFieldsLockScenario> createState() =>
      _ProfileFieldsLockScenarioState();
}

class _ProfileFieldsLockScenarioState extends State<ProfileFieldsLockScenario> {
  /// Applies [lock] (or clears the override when `null`) and reports it.
  ///
  /// [label] is the preset's own wording rather than
  /// `ProfileFieldsLock.toString()` — `profileFieldsLock-result` is a catalog
  /// `result_test_id`, so what it renders is worth keeping deliberate and
  /// readable. Iso the Android sample, the line always starts with `Applied: `.
  Future<void> _apply(
    ScenarioResultSink setResult,
    String label,
    ProfileFieldsLock? lock,
  ) async {
    final octopus = AppScope.of(context).octopus;
    demoLog.apiCall('debugOverrideProfileFieldsLock', {
      'lock': lock?.toString() ?? 'null (clear)',
    });
    try {
      await octopus.debugOverrideProfileFieldsLock(lock);
      _applied = lock;
      _appliedLabel = lock == null ? _noOverrideLabel : label;
      if (!mounted) return;
      setState(() {});
      setResult(
        lock == null
            ? 'Applied: $_noOverrideLabel. The community config served by the '
                  'backend applies again.'
            : 'Applied: $label. Open the Community tab, then your profile, to '
                  'see the locked fields.',
      );
    } on PlatformException catch (e) {
      setResult(
        e.code == 'UNSUPPORTED_PLATFORM'
            ? 'debugOverrideProfileFieldsLock is unavailable on this build: '
                  '${e.message ?? e.code}'
            : 'debugOverrideProfileFieldsLock failed (${e.code}): '
                  '${e.message ?? 'no message'}',
        isError: true,
      );
    } catch (e) {
      setResult('debugOverrideProfileFieldsLock threw: $e', isError: true);
    }
  }

  /// One catalog preset. [label] carries the `Preset N · ` prefix the catalog
  /// uses on screen; [shortLabel] is what the result line reports.
  ScenarioPreset _preset({
    required String testId,
    required String label,
    required String shortLabel,
    required ProfileFieldsLock? lock,
  }) => ScenarioPreset(
    testId: testId,
    label: label,
    onRun: (setResult) => _apply(setResult, shortLabel, lock),
  );

  @override
  Widget build(BuildContext context) {
    final applied = _applied;
    String state(ProfileFieldLockState? value) => value?.name ?? '— (backend)';
    return ScenarioScaffold(
      title: 'Profile Field Lock',
      api: 'debugOverrideProfileFieldsLock',
      verifyInCommunity: true,
      description:
          'Debug-only: override the community per-field profile lock locally, '
          'then open your profile to see the effect on the profile and edit '
          'screens. A read-only field keeps its value but can no longer be '
          'edited; a disabled bio disappears entirely.',
      youWillSee: 'the locked fields greyed out in the profile editor.',
      note:
          'This is an internal test affordance, not supported public API — it '
          'may change or be removed at any time. Only the bio may be disabled: '
          'nickname and avatar are editable or read-only. It is in-memory and '
          'not persisted: relaunching the app, or switching community, goes '
          'back to the backend config. On iOS it is available through the '
          'CocoaPods integration only; the Swift Package Manager integration '
          'answers UNSUPPORTED_PLATFORM.',
      resultTestId: 'profileFieldsLock-result',
      liveState: KeyValueCard(
        title: 'Live state',
        rows: [
          ('Applied override', _appliedLabel),
          ('nickname', state(applied?.nickname)),
          ('avatar', state(applied?.avatar)),
          ('bio', state(applied?.bio)),
        ],
      ),
      presets: [
        _preset(
          testId: 'qa-preset-profileFieldsLock-1',
          label: 'Preset 1 · All editable (default / no-op)',
          shortLabel: 'All editable (default / no-op)',
          lock: ProfileFieldsLock.allEditable,
        ),
        _preset(
          testId: 'qa-preset-profileFieldsLock-2',
          label: 'Preset 2 · Pseudo + avatar read-only, bio hidden',
          shortLabel: 'Pseudo + avatar read-only, bio hidden',
          lock: const ProfileFieldsLock(
            nickname: ProfileFieldLockState.readOnly,
            avatar: ProfileFieldLockState.readOnly,
            bio: ProfileFieldLockState.disabled,
          ),
        ),
        _preset(
          testId: 'qa-preset-profileFieldsLock-3',
          label: 'Preset 3 · Bio-only editable',
          shortLabel: 'Bio-only editable',
          lock: const ProfileFieldsLock(
            nickname: ProfileFieldLockState.readOnly,
            avatar: ProfileFieldLockState.readOnly,
          ),
        ),
        // qa-preset-profileFieldsLock-clear is a first-class catalog preset,
        // not sample-added UX sugar: it stays rendered even with nothing to
        // clear, so a QA teardown — or an up-front resolve of the id from a
        // clean state — always finds it. Clearing twice is a harmless no-op.
        _preset(
          testId: 'qa-preset-profileFieldsLock-clear',
          label: 'Clear override (backend default)',
          shortLabel: _noOverrideLabel,
          lock: null,
        ),
      ],
    );
  }
}
