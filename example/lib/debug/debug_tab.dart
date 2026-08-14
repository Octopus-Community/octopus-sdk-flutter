import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_state.dart';
import '../widgets/key_value_card.dart';
import 'debug_log.dart';

/// Debug tab — a live, in-app feed of SDK events + API calls plus a snapshot
/// of the streamed state values the SDK exposes.
///
/// Reuses the global [debugLog] recorder (started at app launch by
/// `runOctopusDemo`): it subscribes to `OctopusSDK.eventStream` and records
/// every `demoLog.apiCall(...)` the sample fires, in one merged
/// reverse-chronological buffer. This tab is a read-only view of that buffer,
/// limited to the most recent 100 entries to keep scrolling responsive on long
/// sessions.
///
/// **Public, despite the directory.** It is the Debug bottom-nav tab of the
/// sample (`example/lib/main.dart`), so it ships — the debug log is visible to
/// anyone running the example app from the published package. The genuinely
/// internal surfaces live under `debug/internal/`; see [debugLog].
class DebugTab extends StatefulWidget {
  const DebugTab({super.key});

  @override
  State<DebugTab> createState() => _DebugTabState();
}

class _DebugTabState extends State<DebugTab> {
  /// Cap displayed rows to the most recent N to stay smooth on long sessions.
  static const int _maxDisplayedEntries = 100;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        // The two trailing actions (Copy / Clear) would otherwise left-align
        // the title under Material's iOS centering rule (centered only with
        // < 2 actions). Force centering so this tab matches the others.
        centerTitle: true,
        title: const Text('Debug'),
        actions: [
          MergeSemantics(
            child: Semantics(
              identifier: 'debug-tab-copy-button',
              button: true,
              child: IconButton(
                tooltip: 'Copy log',
                icon: const Icon(Icons.copy),
                onPressed: () => _copyLog(context),
              ),
            ),
          ),
          MergeSemantics(
            child: Semantics(
              identifier: 'debug-tab-clear-button',
              button: true,
              child: IconButton(
                tooltip: 'Clear log',
                icon: const Icon(Icons.delete_outline),
                onPressed: debugLog.clear,
              ),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([app, debugLog]),
        builder: (context, _) {
          final all = debugLog.entries;
          final displayed = all.length > _maxDisplayedEntries
              ? all.sublist(0, _maxDisplayedEntries)
              : all;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(child: _LiveStateSection(app: app)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _LogHeader(shown: displayed.length, total: all.length),
                ),
              ),
              if (displayed.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('No log entries yet.')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList.separated(
                    itemCount: displayed.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) => _LogEntryTile(
                      entry: displayed[i],
                      onTap: () => _showEntryDialog(context, displayed[i]),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _copyLog(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: debugLog.exportText()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Log copied')));
  }

  Future<void> _showEntryDialog(BuildContext context, DebugEntry entry) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _EntryDetailDialog(entry: entry),
    );
  }
}

/// Live snapshot of the SDK's state-shaped streams.
class _LiveStateSection extends StatelessWidget {
  final AppState app;
  const _LiveStateSection({required this.app});

  @override
  Widget build(BuildContext context) {
    return KeyValueCard(
      title: 'Live state',
      rows: [
        ('isInitialised', app.isInitialised.toString()),
        ('connectionState', _formatConnectionState(app.connectionState)),
        ('hasAccess', app.hasAccess?.toString() ?? '—'),
        ('notSeenCount', app.notSeenCount?.toString() ?? '—'),
        (
          'profile.entitlements',
          app.profile == null ? '—' : '${app.profile!.entitlements.length}',
        ),
      ],
    );
  }

  String _formatConnectionState(OctopusConnectionState? state) {
    if (state == null) return '—';
    return switch (state) {
      OctopusNotConnected() => 'notConnected',
      OctopusConnected(:final isGuest) =>
        isGuest ? 'connected (guest)' : 'connected',
    };
  }
}

class _LogHeader extends StatelessWidget {
  final int shown;
  final int total;
  const _LogHeader({required this.shown, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          'Log ($shown${shown < total ? ' of $total' : ''})',
          style: theme.textTheme.titleSmall,
        ),
        const Spacer(),
        Text(
          'newest first',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  final DebugEntry entry;
  final VoidCallback onTap;
  const _LogEntryTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isApi = entry.kind == DebugEntryKind.api;
    final time = entry.time.toIso8601String().substring(11, 19);
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: Icon(
        isApi ? Icons.call_made : Icons.bolt,
        color: isApi ? scheme.primary : scheme.secondary,
      ),
      title: Text(entry.label),
      subtitle: Text(
        entry.detail,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(time, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _EntryDetailDialog extends StatelessWidget {
  final DebugEntry entry;
  const _EntryDetailDialog({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(entry.label),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              entry.time.toIso8601String(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(entry.detail, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: entry.detail));
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Payload copied')));
          },
          child: const Text('Copy'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
