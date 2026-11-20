import 'package:flutter/material.dart';
// The bundled example reads the generated wrapper version without adding a
// public SDK API just for build metadata.
// ignore: implementation_imports
import 'package:octopus_sdk_flutter/src/octopus_sdk_version.dart';

import '../app_state.dart';
import '../design.dart';
import '../update/update_card.dart';
import '../octopus_demo_config.dart';
import '../widgets/open_url.dart';

/// Settings → About: what this build is, and the licences. The sample's one
/// destructive action — Reset Configuration — lives at Settings level, as the
/// last red row of the Support group, not here.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);

    return SampleScaffold(
      appBar: SampleTopAppBar(title: 'About'),
      // A pushed route: nothing above it consumes the bottom system inset the
      // way the app shell's own `SafeArea` does for the tabs. Without this the
      // list scrolls under Android's gesture handle, which crosses whatever
      // label rests there (#359, same defect as Account in #355).
      body: SafeArea(
        child: Semantics(
          identifier: 'about-screen',
          child: ListView(
            padding: const EdgeInsets.all(SampleSpacing.space4),
            children: [
              if (app.updateChecker.isSupported) ...[
                UpdateCard(checker: app.updateChecker),
                const SizedBox(height: 12),
              ],
              SampleSection(
                title: 'Versions',
                identifier: 'about-versions',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SampleKeyValue(
                      'App version',
                      app.sampleVersionLabel ?? '—',
                    ),
                    const SizedBox(height: 6),
                    const SampleKeyValue('SDK version', octopusSdkVersion),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // The shared design link is present only when injected at build.
              if (octopusDesignReferenceUrl.isNotEmpty) ...[
                SampleNavTile(
                  icon: Icons.design_services_outlined,
                  title: 'Design reference',
                  subtitle: 'Shared target for the five platforms',
                  identifier: 'about-design-reference-row',
                  onTap: () => openUrlOrCopy(
                    context,
                    octopusDesignReferenceUrl,
                    clipLabel: 'Octopus design reference',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SampleSection(
                title: 'Licences',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open-source notices for what this sample links against.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    const SampleKeyValue('Octopus SDK', 'Proprietary'),
                    const SizedBox(height: 6),
                    const SampleKeyValue('Flutter / Dart', 'BSD-3-Clause'),
                    SampleNavTile(
                      icon: Icons.description_outlined,
                      title: 'Licences',
                      subtitle:
                          'Open-source notices for what this sample links against.',
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
              const SizedBox(height: 16),
              // Flutter attribution — Google's required trademark line, kept at
              // the readability floor.
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Built with the Octopus SDK for Flutter',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: SampleSpacing.space1),
                  Text(
                    'Flutter and the related logo are trademarks of Google LLC.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
