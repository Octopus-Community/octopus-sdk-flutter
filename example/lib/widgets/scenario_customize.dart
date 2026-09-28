import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design.dart';

/// One editable parameter of a scenario, and the preset values it takes.
///
/// Ported iso from the Android sample (`ui/scenarios/ScenarioCustomize.kt`, PR #488/#489).
///
/// [presetValues] is positional: index *i* is the value preset *i* sets. It must be the
/// same length as the spec's preset labels — see the assertion in [ScenarioCustomizeSpec].
class ScenarioEditableParam {
  const ScenarioEditableParam({
    required this.name,
    required this.type,
    required this.help,
    required this.presetValues,
    required this.value,
    required this.onValueChange,
  });

  /// The parameter name as the shared catalog spells it. Never a re-invented one: a QA
  /// script and a tester both look for the catalog name.
  final String name;
  final String type;
  final String help;
  final List<String> presetValues;
  final String value;
  final ValueChanged<String> onValueChange;
}

/// The customizable surface of one scenario: its presets, its editable parameters, and
/// which catalog parameters those editable ones replace.
class ScenarioCustomizeSpec {
  ScenarioCustomizeSpec({
    required this.presetLabels,
    required this.params,
    required this.replacesCatalogParams,
    required this.onRun,
  }) : assert(
         // A preset that cannot set every field would leave the screen in a state no
         // preset matches — permanently "Custom", with a Reset that resets nothing.
         params.isEmpty ||
             params.every((p) => p.presetValues.length == presetLabels.length),
         'every param must carry one value per preset',
       );

  final List<String> presetLabels;
  final List<ScenarioEditableParam> params;

  /// Catalog parameter names the editable rows above stand in for. The read-only catalog
  /// list filters these out, so a value never appears twice with two different truths.
  final Set<String> replacesCatalogParams;

  /// Runs the scenario.
  ///
  /// The argument names the preset to run when the caller already knows it (a
  /// preset button); `null` means "whatever the fields currently hold". A
  /// preset button must NOT leave it to the matching below: [applyPreset] has
  /// just pushed the new values into the host widget's state, while this spec
  /// still carries the values of the build it was made in — matching against
  /// those would run whichever preset the *previous* values spelled out
  /// (`#355`: tapping "Force fr" from a blank field ran "Reset to system").
  final void Function(int? presetIndex) onRun;

  /// Separator for [valuesKey].
  ///
  /// A **unicode escape**, deliberately, and never a raw control byte: a raw one lands in
  /// the source file and blinds `scan-client-names.sh`, whose `grep -nI` treats the file
  /// as binary and skips it silently. The scar is Android's; the rule is shared.
  static const String _separator = '\u0000';

  /// A comparable snapshot of every field's current value.
  String get valuesKey => params.map((p) => p.value).join(_separator);

  /// The same snapshot for preset [index], without applying it.
  String presetValuesKey(int index) =>
      params.map((p) => p.presetValues[index]).join(_separator);

  /// Which preset the fields currently spell out, or `null` when they spell out none.
  int? get matchingPreset {
    if (params.isEmpty) return null;
    for (var i = 0; i < presetLabels.length; i++) {
      if (presetValuesKey(i) == valuesKey) return i;
    }
    return null;
  }

  void applyPreset(int index) {
    for (final param in params) {
      param.onValueChange(param.presetValues[index]);
    }
  }
}

/// Holders that survive a rebuild — the Dart equivalent of the `rememberSaveable` state
/// `rememberScenarioCustomizeState` hands the Android version.
class ScenarioCustomizeHolders {
  bool customizing = false;
  int lastPreset = 0;
  String? lastRunValues;
}

/// The preset / Custom / stale state machine.
///
/// Built fresh on every rebuild over the same [ScenarioCustomizeHolders], exactly as the
/// Android version is rebuilt on every recomposition over the same remembered holders —
/// which is what makes the unit test able to drive it without a widget tree.
///
/// [lastCallRank] is the screen's own count of calls that have started. It is what keeps a
/// result the *ViewModel* remembers from a previous visit out of the staleness comparison:
/// with no call made from this editor, nothing can be stale.
class ScenarioCustomizeState {
  ScenarioCustomizeState({
    required this.spec,
    required ScenarioCustomizeHolders holders,
    required this.lastCallRank,
    this.onChanged,
  }) : _holders = holders;

  final ScenarioCustomizeSpec? spec;
  final ScenarioCustomizeHolders _holders;
  final int lastCallRank;

  /// Notifies the host widget that a holder moved, so it can rebuild.
  final VoidCallback? onChanged;

  bool get customizing => _holders.customizing;
  int get lastPreset => _holders.lastPreset;
  String? get lastRunValues => _holders.lastRunValues;

  /// The fields spell out no preset — the dashed **Custom** chip.
  bool get isCustom => spec != null && spec!.matchingPreset == null;

  /// The result on screen was produced by values the fields no longer hold.
  ///
  /// Compared against a **per-call snapshot** of what actually ran, not against the preset
  /// index: a preset button taken while customizing runs the preset's values, so the fresh
  /// result must not immediately hide behind "values changed".
  bool get resultStale =>
      lastCallRank > 0 &&
      spec != null &&
      _holders.lastRunValues != null &&
      spec!.valuesKey != _holders.lastRunValues;

  void enterCustomize() {
    // Anchor "Reset to preset" to the preset the fields hold right now. Nothing moves it
    // while the person types: a field cleared on its way to a new value transiently equals
    // another preset, and Reset restoring *that* one is what the target forbids.
    //
    // Fields already custom on entry (values left over from an earlier visit) match no
    // preset, so the anchor deliberately stays where it was: the last preset run from this
    // screen, or Preset 1 on a fresh visit.
    final matching = spec?.matchingPreset;
    if (matching != null) _holders.lastPreset = matching;
    _holders.customizing = true;
    onChanged?.call();
  }

  /// Restores the preset Customize was entered with — **not** one the fields transiently
  /// matched while the tester was typing. Landing on preset 3's value on the way to "de"
  /// must not make Reset mean "back to preset 3".
  void resetToPreset() {
    spec?.applyPreset(_holders.lastPreset);
    _holders.customizing = false;
    onChanged?.call();
  }

  void onEdit(ScenarioEditableParam param, String value) {
    param.onValueChange(value);
    onChanged?.call();
  }

  /// Runs with the current field values.
  void run() {
    final current = spec;
    if (current == null) return;
    _holders.lastRunValues = current.valuesKey;
    current.onRun(null);
    onChanged?.call();
  }

  /// Applies preset [index], re-locks the fields, and runs it.
  ///
  /// The snapshot recorded is the preset's own values, taken before [ScenarioCustomizeSpec]
  /// is rebuilt from the new field values — otherwise the run would be compared against
  /// whatever the fields held a moment ago and the result would show as stale on arrival.
  void runPreset(int index) {
    final current = spec;
    if (current == null) return;
    final snapshot = current.presetValuesKey(index);
    current.applyPreset(index);
    _holders.lastPreset = index;
    _holders.customizing = false;
    _holders.lastRunValues = snapshot;
    // By index, never by matching: [applyPreset] above moved the host's
    // values, not this spec's own copy of them.
    current.onRun(index);
    onChanged?.call();
  }
}

/// The "Parameters" block body: preset state, editable rows while customizing, then the
/// read-only catalog parameters the editable rows do not replace.
class ScenarioParametersBlock extends StatelessWidget {
  const ScenarioParametersBlock({
    super.key,
    required this.state,
    required this.catalogParams,
  });

  final ScenarioCustomizeState state;

  /// Catalog parameters as plain name/value lines, for the ones nothing edits.
  final Map<String, String> catalogParams;

  @override
  Widget build(BuildContext context) {
    final spec = state.spec;
    final theme = Theme.of(context);
    final readOnly = {
      for (final entry in catalogParams.entries)
        if (spec == null || !spec.replacesCatalogParams.contains(entry.key))
          entry.key: entry.value,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (spec != null) ...[
          Row(
            children: [
              Expanded(child: _PresetStateRow(state: state)),
              // Deliberately carries no test id: QA drives presets and Run, never the
              // editor. A selector here would freeze a layout decision as a contract.
              TextButton(
                onPressed: state.customizing
                    ? state.resetToPreset
                    : state.enterCustomize,
                child: Text(
                  state.customizing ? 'Reset to preset' : 'Customize ›',
                ),
              ),
            ],
          ),
          if (state.customizing)
            for (final param in spec.params)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: TextFormField(
                  initialValue: param.value,
                  onChanged: (value) => state.onEdit(param, value),
                  decoration: InputDecoration(
                    labelText: '${param.name}: ${param.type}',
                    helperText: param.help.isEmpty ? null : param.help,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              )
          else
            for (final param in spec.params)
              SampleKeyValue(
                param.name,
                param.value.isEmpty ? '(none)' : param.value,
                mono: true,
              ),
        ],
        for (final entry in readOnly.entries)
          SampleKeyValue(entry.key, entry.value, mono: true),
        if (spec == null && readOnly.isEmpty)
          Text(
            'Pre-filled — tap Run.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.74),
            ),
          ),
      ],
    );
  }
}

/// "Preset 2 · Force en" — or the dashed **Custom** chip when the fields match none.
class _PresetStateRow extends StatelessWidget {
  const _PresetStateRow({required this.state});

  final ScenarioCustomizeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = state.spec!;
    if (state.isCustom && theme.brightness == Brightness.dark) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: sampleDarkChipFill,
            border: Border.all(color: sampleDarkChipBorder),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            'Custom',
            style: theme.textTheme.labelMedium?.copyWith(
              color: sampleAccentDark,
            ),
          ),
        ),
      );
    }
    if (state.isCustom) {
      // Align hands the chip loose constraints so it hugs the word instead of
      // stretching across the Expanded slot — Android's chip wraps its label too.
      return Align(
        alignment: Alignment.centerLeft,
        child: CustomPaint(
          painter: _DashedPillPainter(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text('Custom', style: theme.textTheme.labelMedium),
          ),
        ),
      );
    }
    final index = spec.matchingPreset ?? state.lastPreset;
    return Text(
      spec.presetLabels[index],
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.74),
      ),
    );
  }
}

/// The dashed outline of the **Custom** chip — the Android sample draws it with a
/// `dashPathEffect(4, 4)` in `drawBehind`; Flutter has no dash effect, so the pill path is
/// walked and stroked 4 px on, 4 px off.
class _DashedPillPainter extends CustomPainter {
  const _DashedPillPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final pill = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(size.height / 2),
        ),
      );
    for (final metric in pill.computeMetrics()) {
      var start = 0.0;
      while (start < metric.length) {
        final end = math.min(start + 4, metric.length);
        canvas.drawPath(metric.extractPath(start, end), paint);
        start += 8;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPillPainter oldDelegate) =>
      oldDelegate.color != color;
}
