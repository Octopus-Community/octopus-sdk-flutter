import 'package:flutter/material.dart';

import '../app_state.dart';
import '../debug/debug_console.dart';
import '../debug/debug_log.dart';
import '../debug/events_log_screen.dart';
import '../design.dart';
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
    final count = debugLog.entries.length;

    return Scaffold(
      appBar: AppBar(title: const SampleAppBarTitle('Developer tools')),
      body: Semantics(
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
          ],
        ),
      ),
    );
  }
}
