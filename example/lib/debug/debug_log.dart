import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';

/// Whether an entry is an SDK event received or an API call the sample made.
enum DebugEntryKind { event, api }

/// One line in the Debug console.
class DebugEntry {
  final DateTime time;
  final DebugEntryKind kind;
  final String label;
  final String detail;

  DebugEntry(this.kind, this.label, this.detail) : time = DateTime.now();
}

/// Records every SDK event (from [OctopusSDK.eventStream]) and every API call
/// the sample makes, so what the SDK did is inspectable from inside the running
/// app. Also keeps a session-long buffer of the *typed* [OctopusEvent]s for the
/// Events scenario.
///
/// Started once at app launch (`installDebugConsole()`, called
/// unconditionally by `runOctopusDemo` in `example/lib/main.dart`) so it
/// captures the whole session: both [OctopusSDK.eventStream] and the typed
/// [OctopusSDK.events] stream are non-replaying broadcasts, so a consumer that
/// subscribes only when its screen opens would miss everything emitted before.
///
/// **Public, despite the directory.** It backs both the full-screen Events
/// log (`debug-open-button` in Settings) and the Debug console sheet
/// (`debug-console-entry`, `lib/debug/debug_console.dart`), plus the Events
/// scenario — all of which ship, so it runs in every build, including the
/// published package and the public mirror. `debug/internal/` is where the
/// genuinely internal surface lives (the QA-tooling-compatibility entrypoint
/// only, as of D1); that is the boundary the mirror denylist cuts on.
class RealDebugLog extends ChangeNotifier implements DemoLogSink {
  /// Hard cap on the persistent typed-event buffer (FIFO trim). Demo-only —
  /// keeps the Events scenario's list responsive on long sessions. The Events
  /// scenario reads [typedEvents] and surfaces this number in its description.
  static const int maxTypedEvents = 50;

  final List<DebugEntry> _entries = [];
  final List<OctopusEvent> _typedEvents = [];
  StreamSubscription<Map<String, dynamic>>? _sub;
  StreamSubscription<OctopusEvent>? _eventsSub;

  /// Newest-first snapshot of the recorded entries.
  List<DebugEntry> get entries => List.unmodifiable(_entries);

  /// Oldest-first snapshot of the typed [OctopusEvent]s captured this session.
  ///
  /// Backs the Events scenario. Because [OctopusSDK.events] is a non-replaying
  /// broadcast, a screen that subscribes only when it opens misses everything
  /// emitted before; reading this persistent buffer instead shows the full
  /// session's events whenever the scenario is opened. Capped at
  /// [maxTypedEvents] (FIFO).
  List<OctopusEvent> get typedEvents => List.unmodifiable(_typedEvents);

  /// Subscribes to the raw SDK event stream (a superset of typed events — it
  /// also carries count/access changes, login/edit requests, etc.) and to the
  /// typed [OctopusSDK.events] stream. Idempotent: `installDebugConsole()`
  /// calls it, and both `runOctopusDemo` and the QA-tooling-compatibility
  /// entrypoint (`lib/debug/internal/main_debug.dart`) call
  /// `installDebugConsole()`, so repeated calls are no-ops.
  void start() {
    _sub ??= OctopusSDK.eventStream.listen((event) {
      final raw = event['event'];
      final type = raw == 'sdkEvent' ? (event['type'] ?? 'sdkEvent') : raw;
      _add(DebugEntry(DebugEntryKind.event, 'event · $type', event.toString()));
    });
    _eventsSub ??= OctopusSDK.events.listen((event) {
      _typedEvents.add(event);
      if (_typedEvents.length > maxTypedEvents) {
        _typedEvents.removeRange(0, _typedEvents.length - maxTypedEvents);
      }
      notifyListeners();
    });
  }

  @override
  void apiCall(String method, [Map<String, Object?> args = const {}]) {
    _add(
      DebugEntry(
        DebugEntryKind.api,
        'api · $method',
        args.isEmpty ? '(no args)' : args.toString(),
      ),
    );
  }

  void _add(DebugEntry entry) {
    _entries.insert(0, entry);
    if (_entries.length > 500) _entries.removeLast();
    notifyListeners();
  }

  /// Clears all recorded entries (the merged event/API feed shown by the
  /// Debug tab). Leaves the typed-event buffer untouched.
  void clear() {
    _entries.clear();
    notifyListeners();
  }

  /// Clears the typed-event buffer only (the Events scenario's local log),
  /// leaving the merged event/API [entries] untouched.
  void clearTypedEvents() {
    if (_typedEvents.isEmpty) return;
    _typedEvents.clear();
    notifyListeners();
  }

  /// Chronological plain-text dump for the copy-to-clipboard action.
  String exportText() => _entries.reversed
      .map((e) => '[${e.time.toIso8601String()}] ${e.label} — ${e.detail}')
      .join('\n');

  /// Chronological JSON dump for the Events log's "Copy as JSON" action.
  ///
  /// One object per entry, oldest first: `time` (ISO-8601), `source`
  /// (`SDK` for an event the SDK emitted, `HOST` for a call the sample made —
  /// the same two pills the list renders), `label` and `detail`. JSON rather
  /// than the plain-text [exportText] because what a tester pastes into a
  /// ticket is usually re-read by tooling, not only by a human.
  String exportJson() {
    final list = _entries.reversed
        .map(
          (e) => {
            'time': e.time.toIso8601String(),
            'source': e.kind == DebugEntryKind.event ? 'SDK' : 'HOST',
            'label': e.label,
            'detail': e.detail,
          },
        )
        .toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _eventsSub?.cancel();
    super.dispose();
  }
}

/// The single Debug-log instance the console reads and the sample logs into.
final RealDebugLog debugLog = RealDebugLog();
