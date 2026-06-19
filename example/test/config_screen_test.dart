import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/config/config_screen.dart';
import 'package:octopus_sdk_flutter_example/config/user_id_registry.dart';

void main() {
  testWidgets(
    'tapping a User ID quick-pick chip fills the field and parks the caret '
    'at the end',
    (tester) async {
      // Render the Config screen on its own — AppScope is only consulted by
      // the Start button (which this test never taps), so the
      // chip-fills-field contract can be exercised without the host
      // ChangeNotifier.
      await tester.pumpWidget(const MaterialApp(home: ConfigScreen()));

      // Pick a chip that is NOT the seed (which already pre-fills the
      // field) so the assertion proves the chip actually overwrote the
      // field, not that it happened to match the initial value.
      expect(
        pickerUserIds.length,
        greaterThanOrEqualTo(2),
        reason: 'Need at least two picker entries to test override',
      );
      final initial = pickerUserIds.first;
      final target = pickerUserIds.firstWhere((id) => id != initial);

      // Sanity: the field starts on the seed.
      final inputFinder = find.bySemanticsIdentifier('config-userId-input');
      expect(inputFinder, findsOneWidget);
      TextEditingController readController() => tester
          .widget<TextField>(
            find.descendant(of: inputFinder, matching: find.byType(TextField)),
          )
          .controller!;
      expect(readController().text, initial);

      // Find and tap the target chip. `bySemanticsIdentifier` walks the
      // resolved SemanticsNode tree, and ActionChip's own button semantics
      // can absorb a `container: false` Semantics wrapper around it — so
      // locate the ActionChip by its label text instead, which always
      // renders into a discoverable Text widget.
      final chipFinder = find.widgetWithText(ActionChip, target);
      expect(chipFinder, findsOneWidget);
      await tester.tap(chipFinder);
      await tester.pump();

      final controller = readController();
      expect(controller.text, target);
      expect(controller.selection.baseOffset, target.length);
      expect(controller.selection.extentOffset, target.length);
    },
  );
}
