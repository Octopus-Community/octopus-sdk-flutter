import 'package:flutter/material.dart';

import '../app_state.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_scaffold.dart';

/// Locale scenario — `overrideDefaultLocale`.
class LocaleScenario extends StatelessWidget {
  const LocaleScenario({super.key});

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
      resultTestId: 'locale-result',
      liveState: KeyValueCard(
        title: 'Live state',
        rows: [('Locale override', app.localeChoice.label)],
      ),
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-locale-1',
          label: 'Preset 1 · Force fr',
          onRun: (setResult) async {
            await app.setLocale(LocaleChoice.fr);
            setResult(
              'Locale override → fr. Open the Community tab to see it.',
            );
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-locale-2',
          label: 'Preset 2 · Force en',
          onRun: (setResult) async {
            await app.setLocale(LocaleChoice.en);
            setResult(
              'Locale override → en. Open the Community tab to see it.',
            );
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-locale-3',
          label: 'Preset 3 · Reset to system',
          onRun: (setResult) async {
            await app.setLocale(LocaleChoice.system);
            setResult('Locale override reset to system default.');
          },
        ),
      ],
    );
  }
}
