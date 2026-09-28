import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_scaffold.dart';

/// The content options currently overridden on the SDK, and the label of the
/// preset that applied them — `null` / "none (backend default)" when no
/// override is in effect.
///
/// Process-level rather than [State] fields, iso the Android sample's
/// `HostOverrides`: "Verify in Community" pops back to the shell and destroys
/// this scenario's State, so a per-widget field would render "none" on the way
/// back while the SDK is still overridden — the exact confusion the Android
/// override-UX pass removed. Same reasoning as the `_expanded` map of
/// `scenarios_screen.dart`.
ContentOptions? _applied;
String _appliedLabel = _noOverrideLabel;

const String _noOverrideLabel = 'none (backend default)';

/// Content Options scenario — `debugOverrideContentOptions`.
///
/// Debug-only affordance (native `@InternalOctopusApi` /
/// `@_spi(OctopusInternalTesting)`, **not** supported public API) that
/// overrides the community's per-content-type creation options locally,
/// without a backend-driven config. Each preset turns one affordance off; open
/// the post composer (or a comment / reply input) afterwards to see the
/// matching picture / poll button disappear.
///
/// Preset ids and labels are the shared QA scenario catalog's, verbatim,
/// so the QA pipeline drives Android, iOS and Flutter with the same ids.
class ContentOptionsScenario extends StatefulWidget {
  const ContentOptionsScenario({super.key});

  @override
  State<ContentOptionsScenario> createState() => _ContentOptionsScenarioState();
}

class _ContentOptionsScenarioState extends State<ContentOptionsScenario> {
  /// Applies [options] (or clears the override when `null`) and reports it.
  ///
  /// [label] is the preset's own wording rather than `ContentOptions.toString()`
  /// — `contentOptions-result` is a catalog `result_test_id`, so what it renders
  /// is worth keeping deliberate and readable. Iso the Android sample, the line
  /// always starts with `Applied: `.
  Future<void> _apply(
    ScenarioResultSink setResult,
    String label,
    ContentOptions? options,
  ) async {
    final octopus = AppScope.of(context).octopus;
    demoLog.apiCall('debugOverrideContentOptions', {
      'options': options?.toString() ?? 'null (clear)',
    });
    try {
      await octopus.debugOverrideContentOptions(options);
      _applied = options;
      _appliedLabel = options == null ? _noOverrideLabel : label;
      if (!mounted) return;
      setState(() {});
      setResult(
        options == null
            ? 'Applied: $_noOverrideLabel. The community config served by the '
                  'backend applies again.'
            : 'Applied: $label. Open the Community tab and start a post '
                  '(or a comment / reply) to see the matching affordance gone.',
      );
    } on PlatformException catch (e) {
      setResult(
        e.code == 'UNSUPPORTED_PLATFORM'
            ? 'debugOverrideContentOptions is unavailable on this build: '
                  '${e.message ?? e.code}'
            : 'debugOverrideContentOptions failed (${e.code}): '
                  '${e.message ?? 'no message'}',
        isError: true,
      );
    } catch (e) {
      setResult('debugOverrideContentOptions threw: $e', isError: true);
    }
  }

  /// One catalog preset. [label] carries the `Preset N · ` prefix the catalog
  /// uses on screen; [shortLabel] is what the result line reports.
  ScenarioPreset _preset({
    required String testId,
    required String label,
    required String shortLabel,
    required ContentOptions? options,
  }) => ScenarioPreset(
    testId: testId,
    label: label,
    onRun: (setResult) => _apply(setResult, shortLabel, options),
  );

  @override
  Widget build(BuildContext context) {
    final applied = _applied;
    String flag(bool? value) => value == null ? '— (backend)' : '$value';
    return ScenarioScaffold(
      title: 'Content Options',
      api: 'debugOverrideContentOptions',
      verifyInCommunity: true,
      description:
          'Debug-only: override the community content options locally, then '
          'open the post composer (or a comment / reply input) to see the '
          'matching picture / poll affordance disappear. It governs creation, '
          'not the display of content that already exists.',
      youWillSee: 'the composer offering only the allowed content types.',
      note:
          'This is an internal test affordance, not supported public API — it '
          'may change or be removed at any time. It is in-memory and not '
          'persisted: relaunching the app, or switching community, goes back '
          'to the backend config. On iOS it is available through the CocoaPods '
          'integration only; the Swift Package Manager integration answers '
          'UNSUPPORTED_PLATFORM.',
      resultTestId: 'contentOptions-result',
      liveState: KeyValueCard(
        title: 'Live state',
        rows: [
          ('Applied override', _appliedLabel),
          ('post.enablePictures', flag(applied?.post.enablePictures)),
          ('post.enablePolls', flag(applied?.post.enablePolls)),
          ('comment.enablePictures', flag(applied?.comment.enablePictures)),
          ('reply.enablePictures', flag(applied?.reply.enablePictures)),
        ],
      ),
      presets: [
        _preset(
          testId: 'qa-preset-contentOptions-1',
          label: 'Preset 1 · All enabled (default / no-op)',
          shortLabel: 'All enabled (default / no-op)',
          options: const ContentOptions(),
        ),
        _preset(
          testId: 'qa-preset-contentOptions-2',
          label: 'Preset 2 · Post: pictures off',
          shortLabel: 'Post: pictures off',
          options: const ContentOptions(
            post: PostOptions(enablePictures: false),
          ),
        ),
        _preset(
          testId: 'qa-preset-contentOptions-3',
          label: 'Preset 3 · Post: polls off',
          shortLabel: 'Post: polls off',
          options: const ContentOptions(post: PostOptions(enablePolls: false)),
        ),
        _preset(
          testId: 'qa-preset-contentOptions-4',
          label: 'Preset 4 · Post: pictures + polls off',
          shortLabel: 'Post: pictures + polls off',
          options: const ContentOptions(
            post: PostOptions(enablePictures: false, enablePolls: false),
          ),
        ),
        _preset(
          testId: 'qa-preset-contentOptions-5',
          label: 'Preset 5 · Comment: pictures off',
          shortLabel: 'Comment: pictures off',
          options: const ContentOptions(
            comment: CommentOptions(enablePictures: false),
          ),
        ),
        _preset(
          testId: 'qa-preset-contentOptions-6',
          label: 'Preset 6 · Reply: pictures off',
          shortLabel: 'Reply: pictures off',
          options: const ContentOptions(
            reply: ReplyOptions(enablePictures: false),
          ),
        ),
        // qa-preset-contentOptions-clear is a first-class catalog preset, not
        // sample-added UX sugar: it stays rendered even with nothing to clear,
        // so a QA teardown — or an up-front resolve of the id from a clean
        // state — always finds it. Clearing twice is a harmless no-op.
        _preset(
          testId: 'qa-preset-contentOptions-clear',
          label: 'Clear override (backend default)',
          shortLabel: _noOverrideLabel,
          options: null,
        ),
      ],
    );
  }
}
