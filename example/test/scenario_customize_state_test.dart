import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/widgets/scenario_customize.dart';

/// Drives [ScenarioCustomizeState] straight through its holders — the same objects the
/// scenario screen keeps across rebuilds — so the preset / Custom / stale state machine is
/// checked without a device. Re-creating the state object over the same holders is exactly
/// what a rebuild (or a restored route) does.
///
/// Ported iso from the Android sample's `ScenarioCustomizeStateTest`.
void main() {
  group('ScenarioCustomizeState', () {
    test(
      'reset restores the preset customize was entered with, not one matched while typing',
      () {
        final f = _Fixture();
        f.state(0).runPreset(0); // fr
        f.state(1).enterCustomize();
        f.edit(f.state(1), ''); // transiently equals preset 3
        f.edit(f.state(1), 'de');
        expect(f.state(1).isCustom, isTrue);

        f.state(1).resetToPreset();

        expect(f.input, 'fr');
        expect(f.holders.customizing, isFalse);
      },
    );

    test(
      'reset restores the preset the fields held on entry, not preset 1',
      () {
        final f = _Fixture();
        f.input =
            'en'; // seeded from app state on mount, no run from this screen yet
        f.state(0).enterCustomize();
        f.edit(f.state(0), 'de');

        f.state(0).resetToPreset();

        expect(f.input, 'en');
        expect(f.holders.lastPreset, 1);
      },
    );

    test('a preset button while customizing re-locks the fields and runs', () {
      final f = _Fixture();
      f.state(0).enterCustomize();
      f.edit(f.state(0), 'de');

      f.state(0).runPreset(1);

      expect(f.input, 'en');
      expect(f.holders.customizing, isFalse);
      expect(f.runs, 1);
      expect(f.holders.lastPreset, 1);
      // The snapshot is what ran ("en"), not what the spec held when the button was
      // tapped ("de") — otherwise the fresh result would hide behind "values changed".
      expect(f.state(1).resultStale, isFalse);
    });

    test(
      'typing a preset value by hand leaves customize open, and so does a rebuild',
      () {
        final f = _Fixture();
        f.state(0).runPreset(0);
        f.state(1).enterCustomize();
        f.edit(f.state(1), 'en'); // equals preset 2, but typed

        // Rebuild / restored route: a new state object over the same holders.
        final restored = f.state(1);

        expect(restored.customizing, isTrue);
        expect(restored.spec!.matchingPreset, 1);
      },
    );

    test('stale only while the fields differ from what actually ran', () {
      final f = _Fixture();
      expect(f.state(0).resultStale, isFalse, reason: 'never run');

      f.state(0).runPreset(0); // runs with fr → rank 1 once the call starts
      expect(f.state(1).resultStale, isFalse, reason: 'just ran');

      f.state(1).enterCustomize();
      f.edit(f.state(1), 'de');
      expect(f.state(1).resultStale, isTrue, reason: 'edited after the run');

      f.edit(f.state(1), 'fr');
      expect(f.state(1).resultStale, isFalse, reason: 'typed back to what ran');

      f.edit(f.state(1), 'de');
      f.state(1).resetToPreset(); // back to fr, which is what ran
      expect(
        f.state(1).resultStale,
        isFalse,
        reason: 'reset to the preset that ran',
      );

      f.edit(f.state(1), 'de');
      f.state(1).run(); // rank 2 once the call starts
      expect(
        f.state(2).resultStale,
        isFalse,
        reason: 'run clears staleness at call start',
      );

      f.state(2).runPreset(1); // fields held "de", the call runs with "en"
      expect(
        f.state(3).resultStale,
        isFalse,
        reason: 'preset button snapshots the values that ran',
      );
      expect(f.runs, 3);
    });

    test(
      'a preset button runs that preset, not the one the stale fields spell out',
      () {
        final f = _Fixture();
        // What the Locale screen mounts with when no override is applied: the
        // field is blank, which is preset 3's own value.
        f.input = '';

        f.state(0).runPreset(0); // "Force fr"

        expect(f.input, 'fr');
        // Before #355 the run was resolved by matching the spec's values — and
        // the spec a button was built from still holds the pre-tap ones, so
        // tapping "Force fr" from a blank field ran preset 3, "Reset to
        // system": the screen then reported (and showed) a reset.
        expect(f.ranPreset, 0);
      },
    );

    test("a result that predates this screen's editor is never stale", () {
      final f = _Fixture();
      // The screen arrives with a remembered call (rank 5) but fresh holders.
      f.input = 'de';
      expect(f.state(5).resultStale, isFalse);
      expect(f.state(5).isCustom, isTrue);
    });
  });
}

/// A one-input `locale` spec: preset 1 = fr, preset 2 = en, preset 3 = blank.
class _Fixture {
  String input = 'fr';
  int runs = 0;

  /// The preset index the last run was told to run, `null` when it was left to
  /// the current field values (Customize's own Run button).
  int? ranPreset;
  final ScenarioCustomizeHolders holders = ScenarioCustomizeHolders();

  ScenarioCustomizeSpec get spec => ScenarioCustomizeSpec(
    presetLabels: const ['Preset 1 · fr', 'Preset 2 · en', 'Preset 3 · none'],
    params: [
      ScenarioEditableParam(
        name: 'locale',
        type: 'String?',
        help: '',
        presetValues: const ['fr', 'en', ''],
        value: input,
        onValueChange: (value) => input = value,
      ),
    ],
    replacesCatalogParams: const {'locale'},
    onRun: (presetIndex) {
      runs++;
      ranPreset = presetIndex;
    },
  );

  /// A fresh state object over the same holders, as each rebuild builds one.
  ScenarioCustomizeState state(int lastCallRank) => ScenarioCustomizeState(
    spec: spec,
    holders: holders,
    lastCallRank: lastCallRank,
  );

  void edit(ScenarioCustomizeState state, String value) =>
      state.onEdit(state.spec!.params.single, value);
}
