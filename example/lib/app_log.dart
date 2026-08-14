import 'package:flutter/widgets.dart';

/// Logging seam for the sample's SDK API calls.
///
/// The app shell and every scenario log their SDK API calls through the global
/// [demoLog]. The public bootstrap (`runOctopusDemo` in `lib/main.dart`) swaps
/// in the real recording sink ([debugLog]) at launch, so the Debug tab — a
/// public bottom-nav tab — shows the merged event/API feed in any build,
/// including the published package.
///
/// Until that bootstrap runs (e.g. a widget test that pumps a scenario
/// directly), [demoLog] stays a [_NoopLogSink]: logging is a no-op so nothing
/// breaks if a call is made before the recorder is installed.
///
/// The QA / internal entrypoint (`lib/debug/internal/main_debug.dart`)
/// additionally installs the Settings → "Open debug console" sheet
/// ([debugConsoleEntryBuilder]); that sheet is the only debug surface that
/// stays internal-only.
abstract class DemoLogSink {
  /// Records an SDK API call made by the sample (method name + payload).
  void apiCall(String method, [Map<String, Object?> args = const {}]);
}

/// No-op sink used until the bootstrap installs the real recorder.
class _NoopLogSink implements DemoLogSink {
  const _NoopLogSink();

  @override
  void apiCall(String method, [Map<String, Object?> args = const {}]) {}
}

/// The active log sink. Set to the real recorder ([debugLog]) by the app
/// bootstrap (`runOctopusDemo`); a no-op [_NoopLogSink] until then.
DemoLogSink demoLog = const _NoopLogSink();

/// Builds the Settings "Debug console" entry widget (the `debug-open-button`).
///
/// `null` unless the QA / internal entrypoint
/// (`lib/debug/internal/main_debug.dart`) installs a builder that returns the
/// open-button wired to the console sheet.
/// The public bootstrap leaves it `null` — the Debug tab is the public debug
/// surface; this Settings sheet is the internal-only one.
WidgetBuilder? debugConsoleEntryBuilder;
