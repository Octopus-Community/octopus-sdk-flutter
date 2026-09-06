import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design.dart';
import 'debug_log.dart';

enum _LogFilter { all, sdk, host }

/// Developer tools → Events log: one live feed of what the SDK emitted (SDK)
/// and what the sample called (HOST), newest first.
///
/// The two sources are told apart by a pill rather than by an icon, because
/// "who did this" is the first question a tester asks of a log line. Copy as
/// JSON hands the whole feed over in one gesture — a ticket usually wants the
/// payload, not a screenshot.
class EventsLogScreen extends StatefulWidget {
  const EventsLogScreen({super.key});

  @override
  State<EventsLogScreen> createState() => _EventsLogScreenState();
}

class _EventsLogScreenState extends State<EventsLogScreen> {
  _LogFilter _filter = _LogFilter.all;

  bool _matches(DebugEntry e) => switch (_filter) {
    _LogFilter.all => true,
    _LogFilter.sdk => e.kind == DebugEntryKind.event,
    _LogFilter.host => e.kind == DebugEntryKind.api,
  };

  Future<void> _copyAsJson() async {
    await Clipboard.setData(ClipboardData(text: debugLog.exportJson()));
    if (mounted) showSampleSnackBar(context, 'Events log copied as JSON');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const SampleAppBarTitle('Events log'),
        actions: [
          Semantics(
            identifier: 'debug-copy-button',
            button: true,
            // An icon, not a label: a text action here pushed the app bar over
            // its width on a 1080px screen — the title ellipsised to
            // "Events l…" and this button laid out at zero width while staying
            // tappable next to Clear.
            child: IconButton(
              tooltip: 'Copy as JSON',
              icon: const Icon(Icons.content_copy_outlined),
              onPressed: _copyAsJson,
            ),
          ),
          Semantics(
            identifier: 'debug-clear-button',
            button: true,
            child: IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.delete_outline),
              onPressed: debugLog.clear,
            ),
          ),
        ],
      ),
      body: Semantics(
        identifier: 'events-log-screen',
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Semantics(
                identifier: 'debug-filter-select',
                container: true,
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_LogFilter>(
                    segments: const [
                      ButtonSegment(value: _LogFilter.all, label: Text('All')),
                      ButtonSegment(value: _LogFilter.sdk, label: Text('SDK')),
                      ButtonSegment(
                        value: _LogFilter.host,
                        label: Text('HOST'),
                      ),
                    ],
                    selected: {_filter},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        setState(() => _filter = s.first),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Semantics(
                identifier: 'debug-log-list',
                container: true,
                child: ListenableBuilder(
                  listenable: debugLog,
                  builder: (context, _) {
                    final entries = debugLog.entries.where(_matches).toList();
                    if (entries.isEmpty) {
                      return const Center(child: Text('No events yet.'));
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) => _EntryTile(entries[i]),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile(this.entry);

  final DebugEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHost = entry.kind == DebugEntryKind.api;
    final time = entry.time.toIso8601String().substring(11, 19);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SourcePill(isHost ? 'HOST' : 'SDK'),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                time,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: sampleMonoFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            entry.detail,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: sampleMonoFamily,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// SDK = the shared identity's accent (navy light / accent blue dark), HOST = amber (the sample spoke).
class _SourcePill extends StatelessWidget {
  const _SourcePill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = label == 'HOST'
        ? sampleAmberFor(brightness)
        : sampleAccent(brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
