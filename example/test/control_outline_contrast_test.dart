import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/branding.dart';
import 'package:octopus_sdk_flutter_example/design.dart';

/// WCAG 2.x contrast ratio between two opaque colors.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Color _outlinedButtonSide(Brightness brightness) => buildAppTheme(
  brightness,
).outlinedButtonTheme.style!.side!.resolve(<WidgetState>{})!.color;

Color _segmentSide(Brightness brightness) => buildAppTheme(
  brightness,
).segmentedButtonTheme.style!.side!.resolve(<WidgetState>{})!.color;

BorderSide? _chipSide(Brightness brightness, Set<WidgetState> states) =>
    WidgetStateProperty.resolveAs<BorderSide?>(
      buildAppTheme(brightness).chipTheme.side,
      states,
    );

void main() {
  group('light theme: control boundaries hold 3:1 (WCAG 1.4.11)', () {
    final surfaces = <String, Color>{
      'card': sampleTintFor(Brightness.light),
      'page': buildAppTheme(Brightness.light).colorScheme.surface,
    };

    test('the light control outline clears 3:1 on the card and page', () {
      for (final entry in surfaces.entries) {
        expect(
          _contrast(sampleLightControlOutline, entry.value),
          greaterThanOrEqualTo(3.0),
          reason: 'on the ${entry.key} surface',
        );
      }
    });

    test('outlined buttons draw the control outline, not the card border', () {
      expect(_outlinedButtonSide(Brightness.light), sampleLightControlOutline);
      expect(
        _contrast(_outlinedButtonSide(Brightness.light), surfaces['card']!),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('segmented buttons draw the control outline', () {
      expect(_segmentSide(Brightness.light), sampleLightControlOutline);
    });

    test('an unselected chip draws the control outline', () {
      expect(
        _chipSide(Brightness.light, <WidgetState>{})?.color,
        sampleLightControlOutline,
      );
    });

    test('a selected chip keeps the Material default', () {
      expect(
        _chipSide(Brightness.light, <WidgetState>{WidgetState.selected}),
        isNull,
      );
    });

    test('the decorative card border stays invisible', () {
      expect(sampleBorderFor(Brightness.light), Colors.transparent);
    });

    testWidgets('a rendered OutlinedButton picks up the light outline', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Scaffold(
            body: OutlinedButton(onPressed: () {}, child: const Text('Force')),
          ),
        ),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(OutlinedButton),
          matching: find.byType(Material),
        ),
      );
      final shape = material.shape! as OutlinedBorder;
      expect(shape.side.color, sampleLightControlOutline);
    });
  });

  group('dark theme: interactive chips hold 3:1', () {
    test('an unselected chip draws the dark control outline', () {
      expect(
        _chipSide(Brightness.dark, <WidgetState>{})?.color,
        sampleDarkControlOutline,
      );
    });

    test('a selected chip draws the accent', () {
      final side = _chipSide(Brightness.dark, <WidgetState>{
        WidgetState.selected,
      });
      expect(side?.color, sampleAccentDark);
      expect(
        _contrast(sampleAccentDark, sampleDarkCard),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('outlined buttons keep the dark control outline', () {
      expect(_outlinedButtonSide(Brightness.dark), sampleDarkControlOutline);
    });
  });
}
