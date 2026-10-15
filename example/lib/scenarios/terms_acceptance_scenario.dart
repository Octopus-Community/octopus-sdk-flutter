import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_scaffold.dart';

const String _noOverrideLabel = 'none (backend default)';

/// Terms Acceptance (Consent) scenario — `debugOverrideTermsAcceptanceMode`.
///
/// Debug-only affordance (native `@InternalOctopusApi` /
/// `@_spi(OctopusInternalTesting)`, **not** supported public API) that
/// overrides the community's terms-acceptance mode locally, without a
/// backend-driven config. The override is applied live: pick a mode, switch to
/// the Community tab and make a first contribution (post / comment / reply)
/// with a user who has not accepted the terms yet to see the consent sheet.
///
/// Preset ids and labels are the shared QA scenario catalog's, verbatim,
/// so the QA pipeline drives Android, iOS and Flutter with the same ids.
class TermsAcceptanceScenario extends StatefulWidget {
  const TermsAcceptanceScenario({super.key});

  @override
  State<TermsAcceptanceScenario> createState() =>
      _TermsAcceptanceScenarioState();
}

class _TermsAcceptanceScenarioState extends State<TermsAcceptanceScenario> {
  /// Applies [mode] (or clears the override when `null`) and reports it.
  ///
  /// [label] is the preset's own wording rather than the enum's `toString()` —
  /// `termsAcceptance-result` is a catalog `result_test_id`, so what it renders
  /// is worth keeping deliberate and readable. Iso the Android sample's sibling
  /// override sections, the line always starts with `Applied: `.
  Future<void> _apply(
    ScenarioResultSink setResult,
    String label,
    TermsAcceptanceMode? mode,
  ) async {
    final app = AppScope.of(context);
    final overrides = app.debugScenarioOverrides;
    demoLog.apiCall('debugOverrideTermsAcceptanceMode', {
      'mode': mode?.name ?? 'null (clear)',
    });
    try {
      await app.octopus.debugOverrideTermsAcceptanceMode(mode);
      if (!identical(overrides, app.debugScenarioOverrides)) return;
      overrides.termsAcceptance = mode == null
          ? null
          : (value: mode, label: label);
      if (!mounted) return;
      setState(() {});
      setResult(
        mode == null
            ? 'Applied: $_noOverrideLabel. The community config served by the '
                  'backend applies again.'
            : 'Applied: $label. Open the Community tab and make a first '
                  'contribution with a user who has not accepted the terms.',
      );
    } on PlatformException catch (e) {
      if (!identical(overrides, app.debugScenarioOverrides)) return;
      setResult(
        e.code == 'UNSUPPORTED_PLATFORM'
            ? 'debugOverrideTermsAcceptanceMode is unavailable on this build: '
                  '${e.message ?? e.code}'
            : 'debugOverrideTermsAcceptanceMode failed (${e.code}): '
                  '${e.message ?? 'no message'}',
        isError: true,
      );
    } catch (e) {
      if (!identical(overrides, app.debugScenarioOverrides)) return;
      setResult('debugOverrideTermsAcceptanceMode threw: $e', isError: true);
    }
  }

  /// One catalog preset. [label] carries the `Preset N · ` prefix the catalog
  /// uses on screen; [shortLabel] is what the result line reports.
  ScenarioPreset _preset({
    required String testId,
    required String label,
    required String shortLabel,
    required TermsAcceptanceMode? mode,
  }) => ScenarioPreset(
    testId: testId,
    label: label,
    onRun: (setResult) => _apply(setResult, shortLabel, mode),
  );

  @override
  Widget build(BuildContext context) {
    final overrides = AppScope.of(context).debugScenarioOverrides;
    return ScenarioScaffold(
      key: ObjectKey(overrides),
      title: 'Terms Acceptance (Consent)',
      api: 'debugOverrideTermsAcceptanceMode',
      verifyInCommunity: true,
      description:
          'Debug-only: override the community terms-acceptance mode locally '
          '(applied live). In an explicit mode a consent sheet is shown at the '
          'first contribution of a user who has not accepted the terms yet; in '
          'the implicit mode a legal disclaimer sits under the editor instead.',
      youWillSee:
          'the consent step in the form you chose, or no consent step at all.',
      note:
          'This is an internal test affordance, not supported public API — it '
          'may change or be removed at any time. Consent is per user: a user '
          'who has already accepted will not be prompted again whatever the '
          'mode, so re-testing the sheet needs a fresh, unaccepted user — '
          'disconnect the SSO user from the Connection scenario, or clear the '
          'app data for a guest, whose acceptance is bound to the install. '
          'Unlike the Android sample this screen reports the mode it applied, '
          'not the mode the SDK resolved: the Flutter bridge exposes neither '
          'the community config nor the profile, so neither the effective mode '
          'nor hasAcceptedCgu can be read back here. The override is in-memory '
          'and not persisted: relaunching the app, or switching community, '
          'goes back to the backend config. '
          'On iOS it works through CocoaPods; through Swift Package Manager it '
          'works when the build reaches the native core module, and otherwise '
          'answers UNSUPPORTED_PLATFORM.',
      resultTestId: 'termsAcceptance-result',
      liveState: KeyValueCard(
        title: 'Live state',
        rows: [
          (
            'Applied override',
            overrides.termsAcceptance?.label ?? _noOverrideLabel,
          ),
          (
            'TermsAcceptanceMode',
            overrides.termsAcceptance?.value.name ?? '— (backend)',
          ),
        ],
      ),
      presets: [
        _preset(
          testId: 'qa-preset-termsAcceptance-1',
          label: 'Preset 1 · Implicit (default / no-op)',
          shortLabel: 'Implicit (default / no-op)',
          mode: TermsAcceptanceMode.implicit,
        ),
        _preset(
          testId: 'qa-preset-termsAcceptance-2',
          label: 'Preset 2 · Explicit — multi checkbox',
          shortLabel: 'Explicit — multi checkbox',
          mode: TermsAcceptanceMode.explicitMultiCheckbox,
        ),
        _preset(
          testId: 'qa-preset-termsAcceptance-3',
          label: 'Preset 3 · Explicit — single checkbox',
          shortLabel: 'Explicit — single checkbox',
          mode: TermsAcceptanceMode.explicitSingleCheckbox,
        ),
        // qa-preset-termsAcceptance-clear is a first-class catalog preset, not
        // sample-added UX sugar: it stays rendered even with nothing to clear,
        // so a QA teardown — or an up-front resolve of the id from a clean
        // state — always finds it. Clearing twice is a harmless no-op.
        _preset(
          testId: 'qa-preset-termsAcceptance-clear',
          label: 'Clear override (backend default)',
          shortLabel: _noOverrideLabel,
          mode: null,
        ),
      ],
    );
  }
}
