import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

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
      api: 'OctopusTheme',
      verifyInCommunity: true,
      description:
          'Switch the embedded Community UI between the SDK default theme, a '
          'custom OctopusTheme (brand colors + bundled logo), that same theme '
          'extended with the background / link / nav-bar-item keys, and those '
          'surface keys alone with no primary colors at all. Open the Community '
          'tab to see it applied.',
      resultTestId: 'theme-result',
      liveState: KeyValueCard(
        title: 'Live state',
        rows: [('Active theme', app.activeThemeLabel)],
      ),
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-theme-1',
          label: 'Preset 1 · Octopus navy',
          onRun: (setResult) async {
            // Passes null, not an explicit theme: `effectiveOctopusTheme()`
            // falls back to `brandOctopusTheme` for a null active theme, so
            // this preset *is* the brand theme — see preset 5 for the actual
            // no-theme-at-all oracle this preset used to be.
            app.setActiveOctopusTheme(null, 'Octopus navy');
            setResult(
              'Embedded view → brand theme (the sample\'s default). '
              'Open the Community tab to see it.',
            );
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-theme-2',
          label: 'Preset 2 · Custom theme (brand colors + logo)',
          onRun: (setResult) async {
            app.setActiveOctopusTheme(
              (brightness) =>
                  brandOctopusTheme(app.logoBase64, brightness: brightness),
              'Custom (brand)',
            );
            setResult(
              'Embedded view → custom brand theme. '
              'Open the Community tab to see it.',
            );
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-theme-3',
          label: 'Preset 3 · Surface keys (background + link + nav-bar item)',
          onRun: (setResult) async {
            app.setActiveOctopusTheme(
              (brightness) =>
                  surfaceOctopusTheme(app.logoBase64, brightness: brightness),
              'Custom (surface keys)',
            );
            setResult(
              'Embedded view → brand theme + background, link and '
              'fontSizeNavBarItem. Open the Community tab: the community '
              'surface turns deep purple and post links turn amber on both '
              'platforms. fontSizeNavBarItem is iOS only — the native Android '
              'typography has no nav-bar-item slot, so nav-bar items keep '
              'their size there.',
            );
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-theme-4',
          label: 'Preset 4 · Surface keys only (no primary colors)',
          onRun: (setResult) async {
            app.setActiveOctopusTheme(
              // No primary colors at all, so nothing here depends on brightness.
              (_) => surfaceOnlyOctopusTheme(),
              'Custom (surface keys only)',
            );
            setResult(
              'Embedded view → background + link only, nothing else set. '
              'Open the Community tab: the surface turns deep purple and links '
              'amber, and every unset slot must still look like the SDK '
              'default — buttons and other primary-colored elements keep the '
              'default near-black primary that adapts to light/dark. A blue '
              'primary here is a bug: it means an unset color was substituted '
              'instead of forwarded as unset.',
            );
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-theme-5',
          label: 'Preset 5 · SDK default (no theme)',
          onRun: (setResult) async {
            // An explicit empty OctopusTheme, not null: null now falls back
            // to the brand theme (preset 1), so reaching the SDK's own
            // unthemed default — the near-black primary — needs a theme
            // instance whose `toMap()` is empty, bypassing that fallback.
            app.setActiveOctopusTheme(
              (_) => const OctopusTheme(),
              'SDK default (no theme)',
            );
            setResult(
              'Embedded view → SDK default theme, nothing set at all. '
              'Open the Community tab: primary renders the SDK\'s own '
              'near-black, not the sample\'s brand color.',
            );
          },
        ),
      ],
    );
  }
}
