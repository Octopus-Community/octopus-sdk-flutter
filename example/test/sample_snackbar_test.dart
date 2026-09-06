import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/design.dart';

/// A confirmation toast must outlive the gesture, not the screen: visual QA
/// caught "Theme applied" still fully painted 13s after the tap and riding
/// across tab changes.
///
/// The cause was `SnackBar.persist`, which DEFAULTS to `action != null` — a
/// snackbar with an Undo button never auto-dismisses, and its `duration` is
/// silently ignored. Nothing about the call site looks wrong, which is exactly
/// why this belongs in the suite rather than in a reviewer's memory.
///
/// Pointed at [showSampleSnackBar] directly rather than at any one caller
/// screen: the trap lives in the shared helper (`design.dart`), so every
/// caller — `AppearanceScreen`'s successor, Config's Language control, any
/// future one — inherits the fix and the coverage together.
void main() {
  Widget harness() => MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showSampleSnackBar(
            context,
            'Theme applied',
            undoLabel: 'Undo',
            onUndo: () {},
          ),
          child: const Text('trigger'),
        ),
      ),
    ),
  );

  testWidgets(
    'a snackbar with an Undo action disappears on its own within ~5s',
    (tester) async {
      await tester.pumpWidget(harness());

      await tester.tap(find.text('trigger'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      expect(find.text('Theme applied'), findsOneWidget);

      // Past the 4s duration plus the exit animation.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(
        find.text('Theme applied'),
        findsNothing,
        reason: 'the snackbar must auto-dismiss, not wait for a tap',
      );
    },
  );

  testWidgets(
    'showing a second snackbar while one is up does not re-post the first',
    (tester) async {
      await tester.pumpWidget(harness());

      await tester.tap(find.text('trigger'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      // A second, distinct call (the other candidate cause: repeated calls
      // keep refreshing the countdown instead of the snackbar's own timer
      // running out on its own).
      await tester.tap(find.text('trigger'));
      await tester.pump();
      // The hide-then-show handoff (exit animation of the first snackbar,
      // entrance animation of the second) chains a few Future-scheduled
      // steps before the second snackbar's own 4s timer even starts. A
      // single large `pump(duration)` only drives one frame at the far end
      // of that jump, so it can land before those chained steps have each
      // had a frame to run — stepping in 1s increments gives every link in
      // the chain a frame to fire on, matching how a real clock would tick.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pumpAndSettle();
      expect(find.text('Theme applied'), findsNothing);
    },
  );
}
