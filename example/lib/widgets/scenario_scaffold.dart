import 'package:flutter/material.dart';

import '../app_state.dart';
import '../design.dart';

/// Publishes a preset's outcome to the shared result panel.
typedef ScenarioResultSink = void Function(String text, {bool isError});

/// The work a preset performs when tapped. Receives the [ScenarioResultSink] so
/// it can report the live outcome into the scenario's result panel.
typedef ScenarioAction = Future<void> Function(ScenarioResultSink setResult);

/// Tri-state of the result panel: untouched (idle), positive outcome
/// (success — green status + check icon), or failure (error — red status +
/// alert icon). Inferred from `setResult(..., isError: bool)`: the first
/// call after mount flips idle → success/error.
enum _ResultStatus { idle, success, error }

/// A single preset action on a scenario screen.
///
/// A preset is a one-tap button: it pre-fills every input itself, so the tap is
/// the only interaction. [testId]
/// is applied verbatim from the scenario catalog (`qa-preset-<scenario>-<n>`)
/// and [label] starts with `Preset N · `.
class ScenarioPreset {
  final String testId;
  final String label;
  final ScenarioAction onRun;

  const ScenarioPreset({
    required this.testId,
    required this.label,
    required this.onRun,
  });
}

/// Shared frame for every scenario screen, in the five zones the sample design
/// gives every scenario, top to bottom:
///
///  1. the monospace API pill and a two-line description,
///  2. **Parameters** — the pre-filled inputs ([parameters]) and the presets
///     that run with them, so nothing is ever mandatory to type,
///  3. **Result** — the raw outcome in a dark code block, with a Success/Error
///     status and the run duration,
///  4. **Verify in Community** — for effects observable in the community,
///  5. **Run** — the primary action, anchored at the bottom, ≥48dp.
///
/// A scenario with several presets keeps them as labelled buttons in zone 2
/// (their catalog ids ride on the buttons); a scenario with exactly one preset
/// promotes it to the anchored Run button, which then carries that same id.
class ScenarioScaffold extends StatefulWidget {
  /// Human title shown in the app bar.
  final String title;

  /// One-line explanation of the SDK capability exercised.
  final String description;

  /// The SDK symbol exercised, rendered as the monospace pill of zone 1.
  final String? api;

  /// The single-tap presets driving this scenario.
  final List<ScenarioPreset> presets;

  /// Catalog `result_test_id` for the live result panel.
  final String resultTestId;

  /// Optional extra live-state widget rendered above the presets
  /// (e.g. the current unseen count or community-access value).
  final Widget? liveState;

  /// Whether this scenario's effect is observable in the community — adds the
  /// secondary "Verify in Community" action of zone 4.
  final bool verifyInCommunity;

  /// A presentation scenario has no result block: the screen it opened *is* the
  /// result (and the Events log carries the trace).
  final bool hidesResult;

  const ScenarioScaffold({
    super.key,
    required this.title,
    required this.description,
    required this.presets,
    required this.resultTestId,
    this.api,
    this.liveState,
    this.verifyInCommunity = false,
    this.hidesResult = false,
  });

  @override
  State<ScenarioScaffold> createState() => _ScenarioScaffoldState();
}

class _ScenarioScaffoldState extends State<ScenarioScaffold> {
  String _result = 'No action run yet.';
  _ResultStatus _status = _ResultStatus.idle;
  String? _runningTestId;
  Duration? _lastDuration;
  bool _descriptionExpanded = false;

  /// Whether any preset has completed at least once — flips the anchored Run
  /// button's label from "Run" to "Run again" (spec 09: the relabel is the
  /// tester's confirmation that the previous tap actually did something,
  /// since a rerun often produces the identical result text).
  bool _hasRunOnce = false;

  /// Spec 09's Running-state floor: the spinner must stay on screen at least
  /// this long even when the call itself resolves faster, so a fast/cached
  /// response still reads as "something happened" rather than the screen not
  /// reacting to the tap at all.
  static const _minRunningDuration = Duration(milliseconds: 300);

  bool get _singlePreset => widget.presets.length == 1;

  void _setResult(String text, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _result = text;
      _status = isError ? _ResultStatus.error : _ResultStatus.success;
    });
  }

  Future<void> _run(ScenarioPreset preset) async {
    setState(() => _runningTestId = preset.testId);
    final started = DateTime.now();
    try {
      await preset.onRun(_setResult);
    } catch (e) {
      _setResult('Unexpected error: $e', isError: true);
    } finally {
      final elapsed = DateTime.now().difference(started);
      if (elapsed < _minRunningDuration) {
        await Future<void>.delayed(_minRunningDuration - elapsed);
      }
      if (mounted) {
        setState(() {
          _runningTestId = null;
          // The spinner floor above pads the *display*, never the reported
          // duration — a 12ms cached call must still read "12 ms", not
          // "≥300 ms". Use the call's own elapsed time, not a fresh
          // DateTime.now() taken after the padding delay.
          _lastDuration = elapsed;
          _hasRunOnce = true;
        });
      }
    }
  }

  /// Zone 4 — leaves the scenario and lands on the Community tab, where the
  /// effect that was just run is visible.
  void _verifyInCommunity() {
    AppScope.of(context).requestTab(2);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: SampleAppBarTitle(widget.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // ── 1 · What this does ──────────────────────────────────────────
          if (widget.api != null) ...[
            Align(alignment: Alignment.centerLeft, child: ApiPill(widget.api!)),
            const SizedBox(height: 8),
          ],
          // Two lines by design: the header must stay a header, not a wall of
          // text between the tester and the Run button. The rest is one tap
          // away rather than deleted — several descriptions carry the
          // --dart-define a scenario needs to work at all.
          Text(
            widget.description,
            style: theme.textTheme.bodyMedium,
            maxLines: _descriptionExpanded ? null : 2,
            overflow: _descriptionExpanded
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () =>
                  setState(() => _descriptionExpanded = !_descriptionExpanded),
              child: Text(_descriptionExpanded ? 'Less' : 'More'),
            ),
          ),
          const SizedBox(height: 16),

          // ── 2 · Parameters ──────────────────────────────────────────────
          SampleSection(
            title: 'Parameters',
            identifier: 'scenario-parameters',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.liveState != null) ...[
                  widget.liveState!,
                  const SizedBox(height: 12),
                ],
                if (_singlePreset)
                  Text(
                    'Pre-filled — tap Run.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  for (final preset in widget.presets) ...[
                    _PresetButton(
                      preset: preset,
                      busy: _runningTestId == preset.testId,
                      enabled: _runningTestId == null,
                      onPressed: () => _run(preset),
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ),

          // ── 3 · Result ──────────────────────────────────────────────────
          if (!widget.hidesResult) ...[
            const SizedBox(height: 20),
            _ResultPanel(
              testId: widget.resultTestId,
              text: _result,
              status: _status,
              duration: _lastDuration,
              // The zone shows a skeleton the instant a preset is tapped,
              // never the previous run's stale text — spec 09's guard
              // against a rerun looking like a no-op tap.
              running: _runningTestId != null,
            ),
          ],

          // ── 4 · Verify in Community ─────────────────────────────────────
          if (widget.verifyInCommunity) ...[
            const SizedBox(height: 16),
            Semantics(
              identifier: 'scenario-verify-button',
              button: true,
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _verifyInCommunity,
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text('Verify in Community'),
                ),
              ),
            ),
          ],
        ],
      ),
      // ── 5 · Run ───────────────────────────────────────────────────────
      bottomNavigationBar: _singlePreset
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _PresetButton(
                preset: widget.presets.single,
                busy: _runningTestId != null,
                enabled: _runningTestId == null,
                onPressed: () => _run(widget.presets.single),
                // "Run" the first time; "Run again" once the tester has seen
                // at least one result, so a rerun with an identical outcome
                // still reads as a deliberate repeat rather than a stuck tap.
                label: _hasRunOnce ? 'Run again' : 'Run',
                primary: true,
              ),
            )
          : null,
    );
  }
}

class _PresetButton extends StatelessWidget {
  final ScenarioPreset preset;
  final bool busy;
  final bool enabled;
  final VoidCallback onPressed;

  /// Overrides [ScenarioPreset.label] — the anchored Run button says "Run".
  final String? label;
  final bool primary;

  const _PresetButton({
    required this.preset,
    required this.busy,
    required this.enabled,
    required this.onPressed,
    this.label,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    // Spec 09: the Running state is a disabled button reading "Running…"
    // next to the spinner, not a bare spinner with no label.
    final child = busy
        ? Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('Running…'),
            ],
          )
        : Text(label ?? preset.label, textAlign: TextAlign.center);

    // MergeSemantics + Semantics(identifier:) puts the catalog test_id on the
    // same accessibility node as the tap action so the automated UI tests can
    // look the button up by id (resource-id / accessibility id).
    return MergeSemantics(
      child: Semantics(
        identifier: preset.testId,
        button: true,
        child: SizedBox(
          width: double.infinity,
          height: primary ? 48 : null,
          child: primary
              ? FilledButton(
                  onPressed: enabled ? onPressed : null,
                  child: child,
                )
              : FilledButton.tonal(
                  onPressed: enabled ? onPressed : null,
                  child: child,
                ),
        ),
      ),
    );
  }
}

/// Zone 3 — the raw outcome, verbatim, in a dark code block, under a status
/// line that says success/failure and how long the call took.
class _ResultPanel extends StatelessWidget {
  final String testId;
  final String text;
  final _ResultStatus status;
  final Duration? duration;

  /// True from the instant a preset is tapped until it settles. Spec 09: the
  /// zone must show a skeleton the moment Run is pressed — never the
  /// previous call's stale text, which would make a rerun look like a no-op.
  final bool running;

  const _ResultPanel({
    required this.testId,
    required this.text,
    required this.status,
    required this.duration,
    required this.running,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    final (Color accent, IconData icon, String label) = running
        ? (
            theme.colorScheme.onSurfaceVariant,
            Icons.hourglass_empty,
            'Running…',
          )
        : switch (status) {
            _ResultStatus.error => (
              sampleDangerFor(brightness),
              Icons.error_outline,
              'Error',
            ),
            _ResultStatus.success => (
              sampleGreenFor(brightness),
              Icons.check_circle_outline,
              'Success',
            ),
            _ResultStatus.idle => (
              theme.colorScheme.onSurfaceVariant,
              Icons.terminal,
              'Idle',
            ),
          };

    return SampleSection(
      title: 'Result',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 4),
          Text(
            running || duration == null
                ? label
                : '$label · ${duration!.inMilliseconds} ms',
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      child: running
          ? const _ResultSkeleton()
          : SampleCodeBlock(text, identifier: testId),
    );
  }
}

/// Placeholder painted over the Result code block while a preset is running,
/// so the zone visibly changes on every tap instead of holding the previous
/// call's text on screen.
class _ResultSkeleton extends StatelessWidget {
  const _ResultSkeleton();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bar = sampleAccent(brightness).withValues(alpha: 0.24);

    Widget line(double widthFactor) => FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: bar,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: sampleCodeSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line(0.85),
          const SizedBox(height: 8),
          line(0.6),
          const SizedBox(height: 8),
          line(0.4),
        ],
      ),
    );
  }
}
