import 'package:flutter/material.dart';

import '../app_state.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_customize.dart';
import '../widgets/scenario_scaffold.dart';

/// Locale scenario — `overrideDefaultLocale`.
class LocaleScenario extends StatefulWidget {
  const LocaleScenario({super.key});

  @override
  State<LocaleScenario> createState() => _LocaleScenarioState();
}

class _LocaleScenarioState extends State<LocaleScenario> {
  final ScenarioCustomizeHolders _holders = ScenarioCustomizeHolders();

  /// What the Customize field holds, which is not what the SDK is using.
  ///
  /// Iso the Android sample's `state.localeInput`: binding the field to applied
  /// state would call `overrideDefaultLocale` on every keystroke, so typing `de`
  /// would first override the SDK to `d`.
  String _localeInput = '';

  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    _localeInput = AppScope.of(context).localeTag;
  }

  Future<void> _apply(ScenarioResultSink setResult, String tag) async {
    final trimmed = tag.trim();
    try {
      await AppScope.of(context).setLocaleTag(trimmed);
      setResult(
        trimmed.isEmpty
            ? 'Locale override reset to system default.'
            : 'Locale override → $trimmed. Open the Community tab to see it.',
      );
    } catch (e) {
      setResult('overrideDefaultLocale failed: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ScenarioScaffold(
      title: 'Locale',
      api: 'overrideDefaultLocale',
      verifyInCommunity: true,
      description:
          'Override the locale used by the SDK UI, or reset to the system '
          'locale. Open the Community tab to see the override applied.',
      youWillSee:
          'The Community tab remounts in the new language — labels, empty '
          'states and relative dates all follow the override.',
      note:
          'A tag the SDK ships no translation for falls back to its default '
          'language; the override is still applied.',
      resultTestId: 'locale-result',
      liveState: KeyValueCard(
        title: 'Live state',
        rows: [('Locale override', app.localeLabel)],
      ),
      catalogParams: const {
        'locale':
            'String? — "fr", "en", or blank to reset to the system locale',
      },
      customize: ScenarioCustomize(
        holders: _holders,
        params: [
          ScenarioEditableParam(
            name: 'locale',
            type: 'Locale?',
            help: 'blank — the system default',
            presetValues: const ['fr', 'en', ''],
            value: _localeInput,
            onValueChange: (value) => setState(() => _localeInput = value),
          ),
        ],
        replacesCatalogParams: const {'locale'},
        customRun: (setResult) => _apply(setResult, _localeInput),
      ),
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-locale-1',
          label: 'Preset 1 · Force fr',
          onRun: (setResult) => _apply(setResult, 'fr'),
        ),
        ScenarioPreset(
          testId: 'qa-preset-locale-2',
          label: 'Preset 2 · Force en',
          onRun: (setResult) => _apply(setResult, 'en'),
        ),
        ScenarioPreset(
          testId: 'qa-preset-locale-3',
          label: 'Preset 3 · Reset to system',
          onRun: (setResult) => _apply(setResult, ''),
        ),
      ],
    );
  }
}
