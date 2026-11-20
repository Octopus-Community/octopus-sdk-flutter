import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_scaffold.dart';

const String _noOverrideLabel = 'none (backend default)';

/// Content Options scenario — `debugOverrideContentOptions`.
///
/// Debug-only affordance (native `@InternalOctopusApi` /
/// `@_spi(OctopusInternalTesting)`, **not** supported public API) that
/// overrides the community's content creation and post tap options locally,
/// without a backend-driven config. Open the composer to check creation flags,
/// or tap post images and group names to check navigation.
///
/// Presets retain the shared QA identifier convention. Post tap presets mirror
/// the native iOS sample.
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
    final app = AppScope.of(context);
    final overrides = app.debugScenarioOverrides;
    demoLog.apiCall('debugOverrideContentOptions', {
      'options': options?.toString() ?? 'null (clear)',
    });
    try {
      await app.octopus.debugOverrideContentOptions(options);
      if (!identical(overrides, app.debugScenarioOverrides)) return;
      overrides.contentOptions = options == null
          ? null
          : (value: options, label: label);
      if (!mounted) return;
      setState(() {});
      setResult(
        options == null
            ? 'Applied: $_noOverrideLabel. The community config served by the '
                  'backend applies again.'
            : 'Applied: $label. Open the Community tab to check the composer '
                  'or tap post images and group names to check navigation.',
      );
    } on PlatformException catch (e) {
      if (!identical(overrides, app.debugScenarioOverrides)) return;
      setResult(
        e.code == 'UNSUPPORTED_PLATFORM'
            ? 'debugOverrideContentOptions is unavailable on this build: '
                  '${e.message ?? e.code}'
            : 'debugOverrideContentOptions failed (${e.code}): '
                  '${e.message ?? 'no message'}',
        isError: true,
      );
    } catch (e) {
      if (!identical(overrides, app.debugScenarioOverrides)) return;
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
    final overrides = AppScope.of(context).debugScenarioOverrides;
    final applied = overrides.contentOptions?.value;
    String flag(bool? value) => value == null ? '— (backend)' : '$value';
    return ScenarioScaffold(
      key: ObjectKey(overrides),
      title: 'Content Options',
      api: 'debugOverrideContentOptions',
      verifyInCommunity: true,
      description:
          'Debug-only: override the community content options locally, then '
          'open the composer to check picture / poll affordances, or tap post '
          'images and group names to check navigation. Preset 7 allows an '
          'image without text; a poll alone still requires text. Publishing '
          'also requires a matching backend configuration. Presets 8–10 enable '
          'image taps to open a post, group name taps to open its group, or both. '
          'Images keep fullscreen in post detail and when a feed card only '
          'expands text.',
      youWillSee:
          'the allowed content types in the composer and the selected post tap behaviour.',
      note:
          'This is an internal test affordance, not supported public API — it '
          'may change or be removed at any time. It is in-memory and not '
          'persisted: relaunching the app, or switching community, goes back '
          'to the backend config. '
          'On iOS it works through CocoaPods; through Swift Package Manager it '
          'works when the build reaches the native core module, and otherwise '
          'answers UNSUPPORTED_PLATFORM.',
      resultTestId: 'contentOptions-result',
      liveState: KeyValueCard(
        title: 'Live state',
        rows: [
          (
            'Applied override',
            overrides.contentOptions?.label ?? _noOverrideLabel,
          ),
          ('post.enablePictures', flag(applied?.post.enablePictures)),
          ('post.enablePolls', flag(applied?.post.enablePolls)),
          ('post.textRequired', flag(applied?.post.textRequired)),
          ('post.imageTapOpensPost', flag(applied?.post.imageTapOpensPost)),
          (
            'post.groupNameTapOpensGroup',
            flag(applied?.post.groupNameTapOpensGroup),
          ),
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
        _preset(
          testId: 'qa-preset-contentOptions-7',
          label: 'Preset 7 · Post: text optional with an image',
          shortLabel: 'Post: text optional with an image',
          options: const ContentOptions(post: PostOptions(textRequired: false)),
        ),
        _preset(
          testId: 'qa-preset-contentOptions-8',
          label: 'Preset 8 · Post: image tap opens the post',
          shortLabel: 'Post: image tap opens the post',
          options: const ContentOptions(
            post: PostOptions(imageTapOpensPost: true),
          ),
        ),
        _preset(
          testId: 'qa-preset-contentOptions-9',
          label: 'Preset 9 · Post: group name opens the group',
          shortLabel: 'Post: group name opens the group',
          options: const ContentOptions(
            post: PostOptions(groupNameTapOpensGroup: true),
          ),
        ),
        _preset(
          testId: 'qa-preset-contentOptions-10',
          label: 'Preset 10 · Post: image and group name taps',
          shortLabel: 'Post: image and group name taps',
          options: const ContentOptions(
            post: PostOptions(
              imageTapOpensPost: true,
              groupNameTapOpensGroup: true,
            ),
          ),
        ),
        // Keep clear available even without an override for QA teardown.
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
