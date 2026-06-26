import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../octopus_demo_config.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_scaffold.dart';

/// Stable, intentionally-bogus post id used as a fallback when no demo post id
/// is injected. Exercises the typed-error path via [SetReactionPostNotFoundError]
/// — useful for QA when [octopusDemoPostId] is unset (public builds).
const String _fallbackFakePostId = 'flutter-demo-fake-post-id';

/// setReaction scenario — exercise every [OctopusReactionKind] (heart, joy,
/// mouthOpen, clap, cry, rage) plus `null` (unreact) against a real post id.
///
/// When [octopusDemoPostId] is configured (`OCTOPUS_DEMO_POST_ID` injected at
/// build time, see `octopus_demo_config.dart`), every preset hits a **real**
/// post on the backend — reactions actually land, and the scenario reports
/// [OctopusSuccess]. Falls back to [_fallbackFakePostId] when no demo id is
/// configured, in which case every preset is expected to fail with
/// [SetReactionPostNotFoundError] on the happy connected path — that still
/// proves the typed-error channel works end-to-end. The presets also handle
/// the orthogonal [OctopusConnectionFailure] branch (no network / not
/// authenticated) and surface its concrete subtype so the automated UI tests see
/// exactly what came back.
class SetReactionScenario extends StatefulWidget {
  const SetReactionScenario({super.key});

  @override
  State<SetReactionScenario> createState() => _SetReactionScenarioState();
}

class _SetReactionScenarioState extends State<SetReactionScenario> {
  /// The post id actually hit by every preset: the real demo post id when
  /// [octopusDemoPostId] is configured, otherwise the fake fallback.
  static final String _postId = hasDemoPostId
      ? octopusDemoPostId
      : _fallbackFakePostId;

  /// Latest reaction the user asked for (label form — `null` reads as
  /// `unreact`).
  String _lastReactionLabel = '—';

  /// One-line outcome of the most recent preset run.
  String _lastOutcome = '—';

  /// Sealed labels we surface in the live-state card. Single source of truth so
  /// the live state, the preset label, and the result message all stay in sync.
  static const _heartLabel = 'heart ❤️';
  static const _joyLabel = 'joy 😂';
  static const _mouthOpenLabel = 'mouthOpen 😮';
  static const _clapLabel = 'clap 👏';
  static const _cryLabel = 'cry 😢';
  static const _rageLabel = 'rage 😡';
  static const _unreactLabel = 'unreact (null)';

  Future<void> _run(
    ScenarioResultSink setResult,
    String label,
    OctopusReactionKind? reaction,
  ) async {
    setState(() {
      _lastReactionLabel = label;
      _lastOutcome = 'running…';
    });
    final app = AppScope.of(context);
    try {
      demoLog.apiCall('setReaction', {
        'reaction': reaction == null ? 'null' : reaction.toString(),
        'postId': _postId,
      });
      final result = await app.octopus.setReaction(reaction, _postId);
      switch (result) {
        case OctopusSuccess():
          // Happy path with a real demo post id — the reaction lands on
          // the backend.
          setResult('setReaction($label) → success.');
          _safeOutcome('success');
        case OctopusInvalidArguments<OctopusServerError>(:final errors):
          // Typed business error. With a real demo post id this is rare
          // (e.g. the post was deleted server-side); with the fallback
          // fake id this is the expected happy path (proves the
          // typed-error channel works end-to-end). The outer
          // `<OctopusServerError>` annotation is required for
          // exhaustiveness (see OctopusResult dartdoc); errors are
          // SetReactionError at runtime.
          final error = errors.first;
          final subtype = error.runtimeType.toString();
          final message =
              'setReaction($label) → typed error: $subtype — '
              '${error.errorMessage}.';
          setResult(message);
          _safeOutcome('typed error: $subtype');
        case OctopusConnectionFailure():
          // Connection / auth failures land here when the user isn't
          // connected or the network is down. We surface the concrete
          // OctopusConnectionFailure subtype so the automated UI tests see exactly
          // which one fired.
          final subtype = result.runtimeType.toString();
          final message =
              'setReaction($label) → connection failure: $subtype. The '
              'typed setReaction error path is only reached once the '
              'user is connected.';
          setResult(message);
          _safeOutcome('connection failure: $subtype');
      }
    } catch (e) {
      final message = 'setReaction($label) threw: $e';
      setResult(message, isError: true);
      _safeOutcome('threw: $e');
    }
  }

  /// Guards every post-await `setState` so a popped route doesn't trigger a
  /// "setState() called on an unmounted State" assertion.
  void _safeOutcome(String outcome) {
    if (!mounted) return;
    setState(() => _lastOutcome = outcome);
  }

  @override
  Widget build(BuildContext context) {
    return ScenarioScaffold(
      title: 'setReaction',
      description:
          'Calls OctopusSDK().setReaction(reaction, postId) once per preset, '
          'cycling through every OctopusReactionKind plus `null` (unreact). '
          '${hasDemoPostId ? 'Hits the real OCTOPUS_DEMO_POST_ID — reactions land on the backend.' : 'No OCTOPUS_DEMO_POST_ID configured — falls back to a fake post id and surfaces SetReactionPostNotFoundError (still proves the typed-error channel).'} '
          'When the user is not connected / offline, surfaces the concrete '
          'OctopusConnectionFailure subtype (e.g. OctopusUserNotAuthenticated).',
      resultTestId: 'set-reaction-result',
      liveState: KeyValueCard(
        title: 'Live state',
        rows: [
          (hasDemoPostId ? 'Demo postId' : 'Fallback fake postId', _postId),
          ('Last reaction', _lastReactionLabel),
          ('Last outcome', _lastOutcome),
        ],
      ),
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-set-reaction-1',
          label: 'Preset 1 · React heart ❤️',
          onRun: (setResult) =>
              _run(setResult, _heartLabel, OctopusReactionKind.heart),
        ),
        ScenarioPreset(
          testId: 'qa-preset-set-reaction-2',
          label: 'Preset 2 · React joy 😂',
          onRun: (setResult) =>
              _run(setResult, _joyLabel, OctopusReactionKind.joy),
        ),
        ScenarioPreset(
          testId: 'qa-preset-set-reaction-3',
          label: 'Preset 3 · React mouthOpen 😮',
          onRun: (setResult) =>
              _run(setResult, _mouthOpenLabel, OctopusReactionKind.mouthOpen),
        ),
        ScenarioPreset(
          testId: 'qa-preset-set-reaction-4',
          label: 'Preset 4 · React clap 👏',
          onRun: (setResult) =>
              _run(setResult, _clapLabel, OctopusReactionKind.clap),
        ),
        ScenarioPreset(
          testId: 'qa-preset-set-reaction-5',
          label: 'Preset 5 · React cry 😢',
          onRun: (setResult) =>
              _run(setResult, _cryLabel, OctopusReactionKind.cry),
        ),
        ScenarioPreset(
          testId: 'qa-preset-set-reaction-6',
          label: 'Preset 6 · React rage 😡',
          onRun: (setResult) =>
              _run(setResult, _rageLabel, OctopusReactionKind.rage),
        ),
        ScenarioPreset(
          testId: 'qa-preset-set-reaction-7',
          label: 'Preset 7 · Unreact (null)',
          onRun: (setResult) => _run(setResult, _unreactLabel, null),
        ),
      ],
    );
  }
}
