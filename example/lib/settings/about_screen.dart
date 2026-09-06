import 'package:flutter/material.dart';

import '../app_state.dart';
import '../design.dart';

/// Settings → About: what this build is, and the licences. The sample's one
/// destructive action — Reset Configuration — lives at Settings level, as the
/// last red row of the Support group, not here.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const SampleAppBarTitle('About')),
      body: Semantics(
        identifier: 'about-screen',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SampleSection(
              title: 'About',
              identifier: 'about-versions',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SampleKeyValue(
                    'Sample version',
                    app.sampleVersionLabel ?? '—',
                  ),
                  SampleKeyValue('Built with', 'the Octopus SDK for Flutter'),
                  const SizedBox(height: 4),
                  SampleNavTile(
                    icon: Icons.description_outlined,
                    title: 'Licences',
                    subtitle: 'Open-source licences of every bundled package',
                    identifier: 'about-licences-entry',
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'Octopus Sample for Flutter',
                      applicationVersion: app.sampleVersionLabel,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Flutter attribution — Google's required trademark line, kept at
            // the readability floor.
            Center(
              child: Column(
                children: [
                  Text(
                    'Built with Flutter™',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.74,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Flutter and the related logo are trademarks of Google LLC.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.74,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
