import 'package:flutter/material.dart';

import '../app_state.dart';
import '../debug/debug_console.dart';
import '../scenarios/scenario_copy.dart';
import '../sample_tab.dart';
import '../design.dart';
import '../feature_toggles.dart';
import 'scenario_customize.dart';

/// The Scenarios section a scenario screen was opened from.
///
/// Provided by the Scenarios list around the route it pushes, so the scenario
/// screen can show the section's feature toggle (read-only, see
/// [ScenarioScaffold]) and lead back to that section — without every scenario
/// widget repeating which section it belongs to.
class ScenarioSectionScope extends InheritedWidget {
  const ScenarioSectionScope({
    super.key,
    required this.sectionId,
    required this.featureToggle,
    this.copy,
    this.api,
    required super.child,
  });

  /// Section id — the `<id>` of `scenarios-section-<id>`.
  final String sectionId;
  final ScenarioCopy? copy;
  final String? api;

  /// The feature toggle the section owns, or `null` when it owns none.
  ///
  /// Shown **read-only** on the scenario screen. Read-only is the design
  /// contract's own rule — *a feature toggle is read here, changed in the
  /// list*. A switch on both screens would be two truths about one boolean.
  final FeatureToggle? featureToggle;

  static ScenarioSectionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ScenarioSectionScope>();

  @override
  bool updateShouldNotify(ScenarioSectionScope oldWidget) =>
      copy != oldWidget.copy ||
      api != oldWidget.api ||
      sectionId != oldWidget.sectionId ||
      featureToggle != oldWidget.featureToggle;
}

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

/// The Customize affordance of zone 2, for the scenarios whose parameters have
/// an open value domain.
///
/// The scenario owns the values; this record only says how to show and re-send
/// them. [holders] must survive rebuilds, so it lives on the scenario's own
/// `State` (or in a top-level field for a `StatelessWidget` scenario), never
/// inside `build`.
class ScenarioCustomize {
  const ScenarioCustomize({
    required this.holders,
    required this.params,
    required this.replacesCatalogParams,
    required this.customRun,
  });

  final ScenarioCustomizeHolders holders;

  /// Rebuilt by the scenario on every build, over its live values.
  final List<ScenarioEditableParam> params;

  /// Catalog parameter names the editable rows stand in for — filtered out of
  /// the read-only list so one value never shows twice with two truths.
  final Set<String> replacesCatalogParams;

  /// Sends whatever the fields currently hold. Used when the values match no
  /// preset; when they match one, that preset's own action runs instead, so its
  /// result text is never lost.
  final ScenarioAction customRun;
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

  /// Interactive scenario controls and optional free-form execution fields.
  final Widget? controls;
  final Widget? inputFields;
  final ScenarioPreset? execute;

  /// Whether this scenario's effect is observable in the community — adds the
  /// secondary "Verify in Community" action of zone 4.
  final bool verifyInCommunity;

  /// A presentation scenario has no result block: the screen it opened *is* the
  /// result (and the Events log carries the trace).
  final bool hidesResult;

  /// The promise, in the words the PO checks it against. A run whose expected
  /// outcome lives only in the test plan is a run nobody can judge on the
  /// device.
  final String? youWillSee;

  /// The engineering caveat, last on the screen and deliberately so: it answers
  /// "why can I not do X here?", a question you only have after trying.
  final String? note;

  /// Catalog parameters as plain name/value lines, for zone 2.
  final Map<String, String> catalogParams;

  /// The opt-in editor of zone 2, for scenarios with an open value domain.
  final ScenarioCustomize? customize;

  const ScenarioScaffold({
    super.key,
    required this.title,
    required this.description,
    required this.presets,
    required this.resultTestId,
    this.api,
    this.liveState,
    this.controls,
    this.inputFields,
    this.execute,
    this.verifyInCommunity = false,
    this.hidesResult = false,
    this.youWillSee,
    this.note,
    this.catalogParams = const {},
    this.customize,
  });

  @override
  State<ScenarioScaffold> createState() => _ScenarioScaffoldState();
}

class _ScenarioScaffoldState extends State<ScenarioScaffold> {
  String _result = 'Not run yet';
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

  /// How many calls have started **from this screen**. Zero keeps a result the
  /// app remembers from an earlier visit out of the staleness comparison: with
  /// no call made from this editor, nothing here can be stale.
  int _callRank = 0;

  bool get _singlePreset => widget.presets.length == 1;

  @override
  void initState() {
    super.initState();
    // The feedback breadcrumb. Derived from `resultTestId` ("locale-result")
    // rather than taking a new parameter: every scenario already carries one,
    // and the catalog builds both ids from the same scenario id — a scenario
    // that forgot to pass it would have no result panel to report about.
    final id = widget.resultTestId.endsWith('-result')
        ? widget.resultTestId.substring(
            0,
            widget.resultTestId.length - '-result'.length,
          )
        : widget.resultTestId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).noteBreadcrumb('Scenarios › $id');
    });
  }

  /// The spec for this build, wired so that running with values that spell out
  /// a preset runs *that preset's* own action — its result text included — and
  /// anything else runs the scenario's custom action.
  ScenarioCustomizeState _buildCustomizeState(ScenarioCustomize config) {
    late final ScenarioCustomizeSpec spec;
    spec = ScenarioCustomizeSpec(
      presetLabels: [for (final preset in widget.presets) preset.label],
      params: config.params,
      replacesCatalogParams: config.replacesCatalogParams,
      onRun: (presetIndex) {
        // A preset button says which preset it is; Customize's Execute leaves
        // it to what the fields spell out.
        final matched = presetIndex ?? spec.matchingPreset;
        _run(
          matched != null
              ? widget.presets[matched]
              : ScenarioPreset(
                  // Not a catalog id: this button only exists while the fields
                  // are unlocked, and QA never opens Customize.
                  testId: 'scenario-run',
                  label: 'Execute',
                  onRun: config.customRun,
                ),
        );
      },
    );
    return ScenarioCustomizeState(
      spec: spec,
      holders: config.holders,
      lastCallRank: _callRank,
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  void _setResult(String text, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _result = text;
      _status = isError ? _ResultStatus.error : _ResultStatus.success;
    });
  }

  Future<void> _run(ScenarioPreset preset) async {
    setState(() {
      _runningTestId = preset.testId;
      _callRank++;
    });
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
    AppScope.of(context).requestTab(SampleTab.community.index);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Zone 1's way back to the one place the section's switch can be moved:
  /// the Scenarios tab, on this scenario's own section.
  void _openScenarios() {
    final app = AppScope.of(context);
    final section = ScenarioSectionScope.maybeOf(context);
    if (section == null) {
      app.requestTab(SampleTab.scenarios.index);
    } else {
      app.requestScenariosSection(section.sectionId);
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = widget.customize;
    final customize = config == null ? null : _buildCustomizeState(config);
    // Read from the section the scenario was opened from, so every scenario
    // of a section that owns a switch shows it without each one repeating it.
    final section = ScenarioSectionScope.maybeOf(context);
    final toggle = section?.featureToggle;
    final copy = section?.copy;
    final youWillSee = copy?.youWillSee ?? widget.youWillSee;
    final api = section?.api ?? widget.api;

    return SampleScaffold(
      appBar: SampleTopAppBar(
        title: copy?.title ?? widget.title,
        size: SampleTopBarSize.medium,
        leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
        actions: [
          IconButton(
            tooltip: 'Debug console',
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: () => showDebugConsoleSheet(context),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: PlatformBadge(),
          ),
        ],
      ),
      // The node a QA run anchors on before it looks for anything inside.
      body: SafeArea(
        child: Semantics(
          identifier: 'scenario-detail-screen',
          container: true,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SampleSpacing.space4,
              SampleSpacing.space4,
              SampleSpacing.space4,
              SampleSpacing.space6,
            ),
            children: [
              // ── 1 · What this does ──────────────────────────────────────────
              if (api != null) ...[
                Align(alignment: Alignment.centerLeft, child: ApiPill(api)),
                const SizedBox(height: SampleSpacing.space2),
              ],
              if (copy != null) ...[
                Text(copy.description, style: theme.textTheme.bodyMedium),
                const SizedBox(height: SampleSpacing.space2),
              ],
              // Two lines by design: the header must stay a header, not a wall of
              // text between the tester and the Run button. The rest is one tap
              // away rather than deleted — several descriptions carry the
              // --dart-define a scenario needs to work at all.
              if (copy == null || copy.description != widget.description) ...[
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
                      padding: const EdgeInsets.symmetric(
                        vertical: SampleSpacing.space1,
                      ),
                      minimumSize: const Size(
                        SampleSize.touchMin,
                        SampleSize.touchMin,
                      ),
                      tapTargetSize: MaterialTapTargetSize.padded,
                    ),
                    onPressed: () => setState(
                      () => _descriptionExpanded = !_descriptionExpanded,
                    ),
                    child: Text(_descriptionExpanded ? 'Less' : 'More'),
                  ),
                ),
              ],
              // Still zone 1, when this scenario's section owns a switch: its
              // position, read-only, and the way back to the one place it moves.
              if (toggle != null)
                _FeatureStateLine(
                  toggle: toggle,
                  onOpenScenarios: _openScenarios,
                ),

              const SizedBox(height: SampleSpacing.space2),

              // ── 2 · Parameters ──────────────────────────────────────────────
              SampleScenarioBlock(
                title: 'Try it',
                identifier: 'scenario-parameters',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (youWillSee != null) ...[
                      Semantics(
                        identifier: 'scenario-you-will-see',
                        child: Text('You will see: $youWillSee'),
                      ),
                      const SizedBox(height: SampleSpacing.space3),
                    ],
                    if (widget.controls != null) widget.controls!,
                    if (customize != null ||
                        widget.catalogParams.isNotEmpty) ...[
                      ScenarioParametersBlock(
                        state:
                            customize ??
                            ScenarioCustomizeState(
                              spec: null,
                              holders: ScenarioCustomizeHolders(),
                              lastCallRank: _callRank,
                            ),
                        catalogParams: widget.catalogParams,
                      ),
                      const SizedBox(height: SampleSpacing.space3),
                    ],
                    if (_singlePreset)
                      Text(
                        'Pre-filled — tap Execute.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      for (final (index, preset) in widget.presets.indexed) ...[
                        _PresetButton(
                          preset: preset,
                          busy: _runningTestId == preset.testId,
                          enabled: _runningTestId == null,
                          // With Customize wired, a preset button also re-locks
                          // the fields and snapshots what it ran, so a fresh
                          // result never hides behind "values changed".
                          onPressed: customize == null
                              ? () => _run(preset)
                              : () => customize.runPreset(index),
                        ),
                        const SizedBox(height: SampleSpacing.space2),
                      ],
                    if (widget.inputFields != null) ...[
                      widget.inputFields!,
                      const SizedBox(height: SampleSpacing.space2),
                    ],
                    if (widget.execute != null)
                      _PresetButton(
                        preset: widget.execute!,
                        busy: _runningTestId == widget.execute!.testId,
                        enabled: _runningTestId == null,
                        onPressed: () => _run(widget.execute!),
                        label: 'Execute',
                        primary: true,
                      ),
                    // Customize's own Run, only while the fields are unlocked: the
                    // preset buttons above would overwrite what was just typed.
                    if (customize != null && customize.customizing)
                      Semantics(
                        identifier: 'scenario-run',
                        button: true,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: SampleSize.touchMin,
                          ),
                          child: FilledButton(
                            onPressed: _runningTestId == null
                                ? customize.run
                                : null,
                            child: Text(
                              _hasRunOnce ? 'Execute again' : 'Execute',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              if (widget.liveState != null) ...[
                const SizedBox(height: SampleSpacing.space2),
                widget.liveState!,
              ],

              // ── 3 · Result ──────────────────────────────────────────────────
              if (!widget.hidesResult) ...[
                const SizedBox(height: SampleSpacing.space2),
                if (customize?.resultStale ?? false)
                  // Keep the idle marker and muted message without a framed
                  // Result heading when the displayed outcome no longer applies.
                  Semantics(
                    identifier: 'scenario-result-idle',
                    child: Text(
                      'Not run yet — values changed',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
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
                const SizedBox(height: SampleSpacing.space4),
                Semantics(
                  identifier: 'scenario-verify-button',
                  button: true,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: SampleSize.touchMin,
                    ),
                    child: OutlinedButton.icon(
                      onPressed: _verifyInCommunity,
                      icon: const Icon(Icons.forum_outlined),
                      label: const Text('Verify in Community'),
                    ),
                  ),
                ),
              ],

              // Last, and deliberately so: the caveat answers "why can I not do X
              // here?", a question you only have after trying.
              if (widget.note != null) ...[
                const Divider(height: 32),
                Text(
                  'Note',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: SampleSpacing.space1),
                Semantics(
                  identifier: 'scenario-note',
                  child: Text(
                    widget.note!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      // ── 5 · Run ───────────────────────────────────────────────────────
      bottomNavigationBar: _singlePreset
          ? SampleActionBar(
              child: _PresetButton(
                preset: widget.presets.single,
                busy: _runningTestId != null,
                enabled: _runningTestId == null,
                onPressed: () => _run(widget.presets.single),
                // "Run" the first time; "Run again" once the tester has seen
                // at least one result, so a rerun with an identical outcome
                // still reads as a deliberate repeat rather than a stuck tap.
                label: _hasRunOnce ? 'Execute again' : 'Execute',
                primary: true,
              ),
            )
          : null,
    );
  }
}

/// The read-only feature-state line of zone 1: where the section's switch
/// stands, and a way back to the header that owns it.
///
/// A 48dp touch target rather than an inline text link — the affordance has to
/// survive a large system font and a thumb.
class _FeatureStateLine extends StatelessWidget {
  const _FeatureStateLine({
    required this.toggle,
    required this.onOpenScenarios,
  });

  final FeatureToggle toggle;
  final VoidCallback onOpenScenarios;

  @override
  Widget build(BuildContext context) {
    final enabled = AppScope.of(context).featureToggles[toggle];
    // One accessibility action includes the state and Change label; only the
    // Change button handles pointer taps. Exclude its duplicate semantics.
    return Semantics(
      identifier: 'scenario-feature-state',
      label: '${toggle.stateLine(enabled)}. Change',
      button: true,
      container: true,
      excludeSemantics: true,
      onTap: onOpenScenarios,
      child: SampleBand(
        tone: SampleTone.neutral,
        message: toggle.stateLine(enabled),
        actionLabel: 'Change',
        onAction: onOpenScenarios,
      ),
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
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: double.infinity,
            minHeight: primary ? SampleSize.actionHeight : SampleSize.touchMin,
          ),
          child: SamplePillButton(
            secondary: !primary,
            minHeight: primary ? 56 : 48,
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
    final badgeStatus = running
        ? SampleStatus.running
        : switch (status) {
            _ResultStatus.error => SampleStatus.failed,
            _ResultStatus.success => SampleStatus.passed,
            _ResultStatus.idle => SampleStatus.ready,
          };
    final label = running
        ? 'Running…'
        : switch (status) {
            _ResultStatus.error => 'Failure',
            _ResultStatus.success => 'Success',
            _ResultStatus.idle => 'Idle',
          };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SampleStatusBadge(
          status: badgeStatus,
          label: running || duration == null
              ? label
              : '$label · ${duration!.inMilliseconds} ms',
        ),
        const SizedBox(height: 8),
        running
            ? const _ResultSkeleton()
            : SampleCodeBlock(text, identifier: testId),
      ],
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
    final bar = brightness == Brightness.dark
        ? sampleDarkHover
        : sampleAccent(brightness).withValues(alpha: 0.24);

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
      padding: const EdgeInsets.all(SampleSpacing.space3),
      decoration: BoxDecoration(
        color: brightness == Brightness.dark
            ? sampleDarkCard
            : sampleCodeSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line(0.85),
          const SizedBox(height: SampleSpacing.space2),
          line(0.6),
          const SizedBox(height: SampleSpacing.space2),
          line(0.4),
        ],
      ),
    );
  }
}
