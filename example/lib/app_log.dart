/// Logging seam for the sample's SDK API calls.
///
/// The app shell and every scenario log their SDK API calls through the global
/// [demoLog]. `runOctopusDemo` (`lib/main.dart`) calls `installDebugConsole()`
/// (`lib/debug/debug_console.dart`) unconditionally at launch, which swaps in
/// the real recording sink ([debugLog]) — so the Events log (Settings →
/// Developer tools) is available in every build, including the published
/// package.
///
/// Until that bootstrap runs (e.g. a widget test that pumps a scenario
/// directly), [demoLog] stays a [_NoopLogSink]: logging is a no-op so nothing
/// breaks if a call is made before the recorder is installed.
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
