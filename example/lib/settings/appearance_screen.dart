import 'package:flutter/material.dart';

import '../app_state.dart';
import '../design.dart';
import 'settings_choices.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return SampleScaffold(
      appBar: SampleTopAppBar(title: 'Appearance'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SampleSpacing.space4),
          children: [
            SampleSection(
              title: 'Appearance',
              child: SettingsChoices<AppThemeChoice>(
                segmented: true,
                identifier: 'appearance-mode-select',
                selected: app.configurationChoices.theme,
                options: [
                  for (final mode in AppThemeChoice.values) (mode, mode.label),
                ],
                onChanged: app.setThemeChoice,
              ),
            ),
            const SizedBox(height: SampleSpacing.space4),
            SampleSection(
              title: 'Theme preset',
              child: SettingsChoices<bool>(
                segmented: true,
                identifier: 'appearance-themePreset-select',
                selected: app.configurationChoices.octopusNavyTheme,
                options: const [(true, 'Octopus navy'), (false, 'SDK default')],
                onChanged: app.setThemePreset,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
