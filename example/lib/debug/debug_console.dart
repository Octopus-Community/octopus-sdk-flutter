import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_log.dart';
import '../design.dart';
import 'debug_log.dart';

/// Starts the session recorder and routes the sample's logging into it.
///
/// Called unconditionally by `runOctopusDemo` (`example/lib/main.dart`), so the
/// feed behind Settings → Developer tools → Events log covers the whole
/// session — both SDK streams are non-replaying broadcasts, so a screen that
/// subscribed only when opened would miss everything before.
/// `example/lib/debug/internal/main_debug.dart` also calls it, for QA-tooling
/// path compatibility; the call is idempotent either way.
void installDebugConsole() {
  debugLog.start();
  demoLog = debugLog;
}

/// A draggable console with independent kind filters and text search.
Future<void> showDebugConsoleSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _DebugConsole(),
    );

class _DebugConsole extends StatefulWidget {
  const _DebugConsole();
  @override
  State<_DebugConsole> createState() => _DebugConsoleState();
}

class _DebugConsoleState extends State<_DebugConsole> {
  String _query = '';
  final _kinds = DebugEntryKind.values.toSet();

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: 'debug-console-sheet',
    child: DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, controller) => ListenableBuilder(
        listenable: debugLog,
        builder: (context, _) {
          final entries = filterDebugEntries(debugLog.entries, _query, _kinds);
          return ListView(
            controller: controller,
            padding: const EdgeInsets.all(SampleSpacing.space4),
            children: [
              Text(
                'Debug Console',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Wrap(
                alignment: WrapAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Copy All',
                    icon: const Icon(Icons.copy),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: debugLog.exportText()),
                      );
                      if (context.mounted) {
                        showSampleSnackBar(context, 'Logs copied');
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Clear Log',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: debugLog.clear,
                  ),
                  Semantics(
                    identifier: 'debug-console-close',
                    child: IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search logs...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: SampleSpacing.space2),
              Semantics(
                identifier: 'debug-filter-select',
                child: Wrap(
                  spacing: SampleSpacing.space2,
                  children: [
                    for (final kind in DebugEntryKind.values)
                      FilterChip(
                        label: Text(
                          '${switch (kind) {
                            DebugEntryKind.event => 'Event',
                            DebugEntryKind.state => 'State',
                            DebugEntryKind.api => 'API Call',
                          }} (${debugLog.entries.where((entry) => entry.kind == kind).length})',
                        ),
                        selected: _kinds.contains(kind),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _kinds.add(kind);
                          } else {
                            _kinds.remove(kind);
                          }
                        }),
                      ),
                  ],
                ),
              ),
              Text('${entries.length} of ${debugLog.entries.length} entries'),
              const SizedBox(height: SampleSpacing.space3),
              if (entries.isEmpty) const Text('No matching logs.'),
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: SampleSpacing.space1,
                  ),
                  child: Text(
                    '[${entry.time.toIso8601String().substring(11, 19)}] ${entry.label} — ${entry.detail}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: sampleMonoFamily,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
