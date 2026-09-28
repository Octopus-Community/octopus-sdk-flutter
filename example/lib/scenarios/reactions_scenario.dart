import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../sample_fixtures.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_scaffold.dart';

/// Set, change and remove reactions on the catalog's post.reactionStack.
class ReactionsScenario extends StatefulWidget {
  const ReactionsScenario({super.key});

  @override
  State<ReactionsScenario> createState() => _ReactionsScenarioState();
}

class _ReactionsScenarioState extends State<ReactionsScenario> {
  String get _postId => sampleFixtures.postReactionStack.trim();

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
    if (_postId.isEmpty) {
      setResult('Skipped: post.reactionStack fixture is empty.', isError: true);
      return;
    }
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
          // (e.g. the post was deleted server-side). The outer
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
      title: 'Reactions',
      api: 'setReaction',
      verifyInCommunity: true,
      description:
          'Calls OctopusSDK().setReaction(reaction, postId) once per preset. '
          'Presets 1-3 react, change the reaction, then unreact; presets 4-7 '
          'cover the remaining reaction kinds. '
          'Targets the shared post.reactionStack fixture. '
          'When the user is not connected / offline, surfaces the concrete '
          'OctopusConnectionFailure subtype (e.g. OctopusUserNotAuthenticated).',
      resultTestId: 'reactions-result',
      liveState: KeyValueCard(
        title: 'Live state',
        rows: [
          ('post.reactionStack', _postId),
          ('Last reaction', _lastReactionLabel),
          ('Last outcome', _lastOutcome),
        ],
      ),
      presets: [
        // Presets 1-3 are the capability triad — react, change, unreact — and
        // keep the ids the QA catalog assigns to those three meanings. 4-7 add
        // the remaining kinds.
        ScenarioPreset(
          testId: 'qa-preset-reactions-1',
          label: 'Preset 1 · React heart ❤️',
          onRun: (setResult) =>
              _run(setResult, _heartLabel, OctopusReactionKind.heart),
        ),
        ScenarioPreset(
          testId: 'qa-preset-reactions-2',
          label: 'Preset 2 · Change reaction to joy 😂',
          onRun: (setResult) =>
              _run(setResult, _joyLabel, OctopusReactionKind.joy),
        ),
        ScenarioPreset(
          testId: 'qa-preset-reactions-3',
          label: 'Preset 3 · Unreact (null)',
          onRun: (setResult) => _run(setResult, _unreactLabel, null),
        ),
        ScenarioPreset(
          testId: 'qa-preset-reactions-4',
          label: 'Preset 4 · React mouthOpen 😮',
          onRun: (setResult) =>
              _run(setResult, _mouthOpenLabel, OctopusReactionKind.mouthOpen),
        ),
        ScenarioPreset(
          testId: 'qa-preset-reactions-5',
          label: 'Preset 5 · React clap 👏',
          onRun: (setResult) =>
              _run(setResult, _clapLabel, OctopusReactionKind.clap),
        ),
        ScenarioPreset(
          testId: 'qa-preset-reactions-6',
          label: 'Preset 6 · React cry 😢',
          onRun: (setResult) =>
              _run(setResult, _cryLabel, OctopusReactionKind.cry),
        ),
        ScenarioPreset(
          testId: 'qa-preset-reactions-7',
          label: 'Preset 7 · React rage 😡',
          onRun: (setResult) =>
              _run(setResult, _rageLabel, OctopusReactionKind.rage),
        ),
      ],
    );
  }
}
