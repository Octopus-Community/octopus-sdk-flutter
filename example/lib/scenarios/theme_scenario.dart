import 'package:flutter/material.dart';

import '../app_state.dart';
import '../branding.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_scaffold.dart';

/// Theme scenario — custom [OctopusTheme] applied to the embedded Community UI.
class ThemeScenario extends StatelessWidget {
  const ThemeScenario({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ScenarioScaffold(
      title: 'Theme',
      description:
          'Switch the embedded Community UI between the SDK default theme and a '
          'custom OctopusTheme (brand colors + bundled logo). Open the Community '
          'tab to see it applied.',
      resultTestId: 'theme-result',
      liveState: KeyValueCard(
        title: 'Live state',
        rows: [('Active theme', app.activeThemeLabel)],
      ),
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-theme-1',
          label: 'Preset 1 · Default theme',
          onRun: (setResult) async {
            app.setActiveOctopusTheme(null, 'SDK default');
            setResult(
              'Embedded view → SDK default theme. '
              'Open the Community tab to see it.',
            );
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-theme-2',
          label: 'Preset 2 · Custom theme (brand colors + logo)',
          onRun: (setResult) async {
            app.setActiveOctopusTheme(
              brandOctopusTheme(app.logoBase64),
              'Custom (brand)',
            );
            setResult(
              'Embedded view → custom brand theme. '
              'Open the Community tab to see it.',
            );
          },
        ),
      ],
    );
  }
}
