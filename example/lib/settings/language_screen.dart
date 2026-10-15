import 'package:flutter/material.dart';

import '../app_state.dart';
import '../design.dart';
import 'settings_choices.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  bool _applying = false;

  Future<void> _select(String tag) async {
    final app = AppScope.of(context);
    if (app.localeTag == tag) return;
    setState(() => _applying = true);
    try {
      await app.setLocaleTag(tag);
    } catch (_) {
      if (mounted) showSampleSnackBar(context, 'Could not apply language');
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return SampleScaffold(
      appBar: SampleTopAppBar(title: 'Language'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SampleSpacing.space4),
          children: [
            SampleSection(
              title: 'SDK language',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Applies to the Octopus screens only — the sample itself stays in English.',
                  ),
                  SettingsChoices<String>(
                    identifier: 'language-options',
                    selected: app.localeTag,
                    options: sdkLanguages,
                    onChanged: _applying ? null : _select,
                  ),
                ],
              ),
            ),
            const SizedBox(height: SampleSpacing.space4),
            const Text(
              'The override survives a restart. "Follow system" hands the choice back to the device locale.',
            ),
          ],
        ),
      ),
    );
  }
}
