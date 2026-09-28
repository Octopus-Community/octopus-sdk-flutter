import 'package:flutter/material.dart';

import '../app_state.dart';
import '../debug/debug_console.dart';
import '../debug/debug_log.dart';
import '../debug/events_log_screen.dart';
import '../design.dart';
import '../feature_toggles.dart';
import 'debug_info_screen.dart';

/// Settings → Developer tools. Three entries: what the SDK did (Events log),
/// what this build is (Debug info), and a quick raw-log peek without leaving
/// the current screen (Debug console). Anything else belongs in a scenario.
class DeveloperToolsScreen extends StatefulWidget {
  const DeveloperToolsScreen({super.key});

  @override
  State<DeveloperToolsScreen> createState() => _DeveloperToolsScreenState();
}

class _DeveloperToolsScreenState extends State<DeveloperToolsScreen> {
  @override
  void initState() {
    super.initState();
    // The subtitle counts events live.
    debugLog.addListener(_onLogChanged);
  }

  @override
  void dispose() {
    debugLog.removeListener(_onLogChanged);
    super.dispose();
  }

  void _onLogChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final count = debugLog.entries.length;

    return SampleScaffold(
      appBar: AppBar(title: const SampleAppBarTitle('Developer tools')),
      // A pushed route: nothing above it consumes the bottom system inset the
      // way the app shell's own `SafeArea` does for the tabs. Without this the
      // list scrolls under Android's gesture handle, which crosses whatever
      // label rests there (#359, same defect as Account in #355).
      body: SafeArea(
        child: Semantics(
          identifier: 'devtools-screen',
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SampleSection(
                title: 'Developer tools',
                child: Column(
                  children: [
                    SampleNavTile(
                      icon: Icons.list_alt,
                      title: 'Events log',
                      subtitle: '$count events · live',
                      identifier: 'debug-open-button',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const EventsLogScreen(),
                        ),
                      ),
                    ),
                    SampleNavTile(
                      icon: Icons.bug_report_outlined,
                      title: 'Debug info',
                      subtitle: app.sampleVersionLabel == null
                          ? 'Build and session details'
                          : 'Sample ${app.sampleVersionLabel}',
                      identifier: 'debug-info-entry',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DebugInfoScreen(),
                        ),
                      ),
                    ),
                    SampleNavTile(
                      icon: Icons.terminal,
                      title: 'Debug console',
                      subtitle: 'SDK logs, as a sheet over the current screen',
                      identifier: 'debug-console-entry',
                      onTap: () => showDebugConsoleSheet(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // READ-ONLY: where every feature toggle stands, and where to move
              // it. No switch here on purpose — a toggle is set from the header
              // of its Scenarios section and nowhere else; this card exists so a
              // developer reading Developer tools does not have to leave it to
              // learn what the SDK was configured with.
              //
              // Id divergence accepted: Android hangs these off its API Explorer
              // (`explorer-feature-toggle*`), a screen this sample does not have.
              // Neither id is in the QA catalog, so the Flutter screen's own
              // prefix wins over a name that would point at nothing here.
              SampleSection(
                title: 'Feature toggles (read-only)',
                identifier: 'devtools-feature-toggles-card',
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Set on Scenarios. Shown here so one screen can '
                          'answer "what is on?".',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ),
                    ),
                    for (final toggle in FeatureToggle.values)
                      Semantics(
                        identifier: 'devtools-feature-toggle-${toggle.id}',
                        child: SampleKeyValue(
                          toggle.label,
                          toggle.readOnlyValueLine(app.featureToggles[toggle]),
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
