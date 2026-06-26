import 'package:flutter/material.dart';

/// Publishes a preset's outcome to the shared result panel.
typedef ScenarioResultSink = void Function(String text, {bool isError});

/// The work a preset performs when tapped. Receives the [ScenarioResultSink] so
/// it can report the live outcome into the scenario's result panel.
typedef ScenarioAction = Future<void> Function(ScenarioResultSink setResult);

/// Tri-state of the result panel: untouched (idle), positive outcome
/// (success — green tint + check icon), or failure (error — red tint +
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

/// Shared frame for every scenario screen: title + description, the preset
/// buttons, and a live result/state panel — the surface the automated UI tests read.
class ScenarioScaffold extends StatefulWidget {
  /// Human title shown in the app bar.
  final String title;

  /// One-line explanation of the SDK capability exercised.
  final String description;

  /// The single-tap presets driving this scenario.
  final List<ScenarioPreset> presets;

  /// Catalog `result_test_id` for the live result panel.
  final String resultTestId;

  /// Optional extra live-state widget rendered above the presets
  /// (e.g. the current unseen count or community-access value).
  final Widget? liveState;

  const ScenarioScaffold({
    super.key,
    required this.title,
    required this.description,
    required this.presets,
    required this.resultTestId,
    this.liveState,
  });

  @override
  State<ScenarioScaffold> createState() => _ScenarioScaffoldState();
}

class _ScenarioScaffoldState extends State<ScenarioScaffold> {
  String _result = 'No action run yet.';
  _ResultStatus _status = _ResultStatus.idle;
  String? _runningTestId;

  void _setResult(String text, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _result = text;
      _status = isError ? _ResultStatus.error : _ResultStatus.success;
    });
  }

  Future<void> _run(ScenarioPreset preset) async {
    setState(() => _runningTestId = preset.testId);
    try {
      await preset.onRun(_setResult);
    } catch (e) {
      _setResult('Unexpected error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _runningTestId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          if (widget.liveState != null) ...[
            widget.liveState!,
            const SizedBox(height: 16),
          ],
          for (final preset in widget.presets) ...[
            _PresetButton(
              preset: preset,
              busy: _runningTestId == preset.testId,
              enabled: _runningTestId == null,
              onPressed: () => _run(preset),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          _ResultPanel(
            testId: widget.resultTestId,
            text: _result,
            status: _status,
          ),
        ],
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  final ScenarioPreset preset;
  final bool busy;
  final bool enabled;
  final VoidCallback onPressed;

  const _PresetButton({
    required this.preset,
    required this.busy,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // MergeSemantics + Semantics(identifier:) puts the catalog test_id on the
    // same accessibility node as the tap action so the automated UI tests can look the
    // button up by id (resource-id / accessibility id).
    return MergeSemantics(
      child: Semantics(
        identifier: preset.testId,
        button: true,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: enabled ? onPressed : null,
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(preset.label, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  final String testId;
  final String text;
  final _ResultStatus status;

  const _ResultPanel({
    required this.testId,
    required this.text,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Material 3 has no "successContainer" role — tint the surface with a
    // green that holds up in both light and dark. The shades match the
    // contrast ratios of `errorContainer`/`onErrorContainer` on the
    // default Material 3 palette.
    final (Color bg, Color accent, IconData icon) = switch (status) {
      _ResultStatus.error => (
        scheme.errorContainer,
        scheme.error,
        Icons.error_outline,
      ),
      _ResultStatus.success => (
        isDark ? const Color(0xFF1B5E20) : const Color(0xFFC8E6C9),
        isDark ? const Color(0xFFA5D6A7) : const Color(0xFF1B5E20),
        Icons.check_circle_outline,
      ),
      _ResultStatus.idle => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        Icons.terminal,
      ),
    };

    return Semantics(
      identifier: testId,
      container: true,
      child: Card(
        color: bg,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: accent),
                  const SizedBox(width: 6),
                  Text('Result', style: theme.textTheme.labelLarge),
                ],
              ),
              const SizedBox(height: 8),
              Text(text),
            ],
          ),
        ),
      ),
    );
  }
}
