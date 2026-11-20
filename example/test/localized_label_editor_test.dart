import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:octopus_sdk_flutter_example/widgets/localized_label_editor.dart';

void main() {
  group('LocalizedLabelController.build', () {
    test('off: the single label, auto-translated', () {
      final controller = LocalizedLabelController(
        initialRows: const [('en', 'Open')],
      );
      addTearDown(controller.dispose);
      expect(
        controller.build('Read'),
        const OctopusLocalizedText.autoTranslated('Read'),
      );
    });

    test('on: the rows, with the default language prefilled to en', () {
      final controller = LocalizedLabelController(
        initialRows: const [('en', 'Open'), ('fr', 'Ouvrir')],
      )..perLanguage = true;
      addTearDown(controller.dispose);
      expect(controller.defaultLanguage.text, 'en');
      expect(
        controller.build('ignored'),
        OctopusLocalizedText.perLanguage({
          'en': 'Open',
          'fr': 'Ouvrir',
        }, defaultLanguage: 'en'),
      );
    });

    test('on: the rows are sent unchecked, for the native SDK to judge', () {
      final controller = LocalizedLabelController(
        initialRows: const [('fr', 'Ouvrir')],
      )..perLanguage = true;
      addTearDown(controller.dispose);
      expect(
        controller.build('ignored'),
        OctopusLocalizedText.perLanguage({
          'fr': 'Ouvrir',
        }, defaultLanguage: 'en'),
      );
    });
  });

  testWidgets('the switch reveals the rows, which can be added and removed', (
    tester,
  ) async {
    final controller = LocalizedLabelController(
      initialRows: const [('en', 'Open')],
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LocalizedLabelEditor(
              controller: controller,
              testIdPrefix: 'test-label',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Default language'), findsNothing);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(controller.perLanguage, isTrue);
    expect(find.text('Default language'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);

    await tester.tap(find.text('Add a language'));
    await tester.pump();
    expect(controller.rows, hasLength(2));

    await tester.tap(find.byTooltip('Remove this language').first);
    await tester.pump();
    expect(controller.rows, hasLength(1));
  });
}
