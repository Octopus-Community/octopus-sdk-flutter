import 'package:flutter/material.dart';

import '../app_state.dart';
import '../design.dart';
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
      appBar: AppBar(title: const SampleAppBarTitle('About')),
      // A pushed route: nothing above it consumes the bottom system inset the
      // way the app shell's own `SafeArea` does for the tabs. Without this the
      // list scrolls under Android's gesture handle, which crosses whatever
      // label rests there (#359, same defect as Account in #355).
      body: SafeArea(
        child: Semantics(
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
                    // The visible trace of the common base: one row, opening the
                    // design target the five platforms implement, so "same UX on
                    // five platforms" is a claim a reader can check from inside
                    // the app. Absent rather than dead when no target URL was
                    // injected into the build — the URL is not in the source,
                    // because this file reaches the public mirror.
                    if (octopusDesignReferenceUrl.isNotEmpty)
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
      ),
    );
  }
}
