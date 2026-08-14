import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
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

  testWidgets(
    'a restored config seeds every field it still carries — the key is not '
    'one of them',
    (tester) async {
      // What `AppState.bootstrap` hands over when it refuses to auto-start a
      // config (custom key: never persisted, so it resolves to no key). The
      // user should get their other choices back and re-enter only the key.
      const restored = DemoConfig(
        apiKeySource: ApiKeySource.custom,
        userId: 'restored-user',
        theme: AppThemeChoice.dark,
        serverEnv: ServerEnv.prod,
      );

      await tester.pumpWidget(
        const MaterialApp(home: ConfigScreen(initialConfig: restored)),
      );

      final inputFinder = find.bySemanticsIdentifier('config-userId-input');
      final userIdField = tester.widget<TextField>(
        find.descendant(of: inputFinder, matching: find.byType(TextField)),
      );
      expect(userIdField.controller!.text, 'restored-user');
      expect(
        userIdField.controller!.text,
        isNot(pickerUserIds.first),
        reason: 'must be the restored id, not the default seed',
      );

      // The pasted key is gone: every other text field on the screen (the
      // custom-key input) comes up empty. Assert the count first — without
      // it the loop below would pass vacuously if the custom-key field ever
      // stopped being rendered.
      expect(find.byType(TextField), findsNWidgets(2));
      final otherFields = tester
          .widgetList<TextField>(find.byType(TextField))
          .where((f) => f.controller != userIdField.controller);
      for (final field in otherFields) {
        expect(field.controller!.text, isEmpty);
      }
    },
  );

  testWidgets(
    'Start stays disabled until a custom key is pasted, and enables on typing',
    (tester) async {
      // The state a restored custom-key config lands in. Starting from here
      // would initialise the SDK with an empty key against production, so the
      // button must wait for the paste.
      const restored = DemoConfig(
        apiKeySource: ApiKeySource.custom,
        userId: 'restored-user',
        theme: AppThemeChoice.system,
        serverEnv: ServerEnv.prod,
      );

      // Start is the last child of a ListView and falls outside the default
      // 800x600 test viewport, so it is never built there. Give the test a
      // tall surface rather than scrolling — the button's enabled state is
      // what's under test, not the scrolling.
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: ConfigScreen(initialConfig: restored)),
      );

      // Located by label, not by `config-start-button`: the button sits under
      // a MergeSemantics, which folds the identifier into the button's own
      // node, so a descendant-of-identifier finder comes back empty.
      FilledButton readStartButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Start'),
      );

      expect(
        readStartButton().onPressed,
        isNull,
        reason: 'no key pasted yet — Start must be inert',
      );

      final customField = find.ancestor(
        of: find.text('Custom API key'),
        matching: find.byType(TextField),
      );
      expect(customField, findsOneWidget);
      await tester.enterText(customField, 'example-pasted-key');
      await tester.pump();

      expect(readStartButton().onPressed, isNotNull);
    },
  );
}
