import 'package:flutter/material.dart';

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

/// Settings → Developer tools → Debug console: the same merged SDK/HOST feed
/// as Events log, as a **sheet over the current screen** (spec 07) rather
/// than a full push — a quick "what just happened" glance that doesn't lose
/// the tester's place on whichever screen they were checking.
Future<void> showDebugConsoleSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Semantics(
      identifier: 'debug-console-sheet',
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          final theme = Theme.of(context);
          return Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Debug console',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Semantics(
                      identifier: 'debug-console-close',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: debugLog,
                  builder: (context, _) {
                    final entries = debugLog.entries;
                    if (entries.isEmpty) {
                      return const Center(child: Text('No SDK logs yet.'));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: entries.length,
                      itemBuilder: (context, i) {
                        final e = entries[i];
                        final time = e.time.toIso8601String().substring(11, 19);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '[$time] ${e.label} — ${e.detail}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: sampleMonoFamily,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
