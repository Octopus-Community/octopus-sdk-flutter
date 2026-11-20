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

Color _segmentSide(
  Brightness brightness, [
  Set<WidgetState> states = const {},
]) => buildAppTheme(
  brightness,
).segmentedButtonTheme.style!.side!.resolve(states)!.color;

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

    test('a selected chip has no outline', () {
      expect(
        _chipSide(Brightness.light, <WidgetState>{WidgetState.selected}),
        const BorderSide(color: Colors.transparent),
      );
    });

    test('the decorative card border uses the shared border token', () {
      expect(sampleBorderFor(Brightness.light), sampleLightBorder);
    });

    test('light borders retain their original color and one-pixel width', () {
      final theme = buildAppTheme(Brightness.light);
      expect(sampleOutlineWidthFor(Brightness.light), 1);
      expect(theme.inputDecorationTheme.enabledBorder!.borderSide.width, 1);
      expect(
        sampleScenarioBorderFor(Brightness.light),
        sampleAccent(Brightness.light).withValues(alpha: .35),
      );
      expect(theme.outlinedButtonTheme.style!.side!.resolve({})!.width, 1);
      expect(theme.segmentedButtonTheme.style!.side!.resolve({})!.width, 1);
      expect(_chipSide(Brightness.light, {})!.width, 1);
      expect((theme.cardTheme.shape! as OutlinedBorder).side.width, 1);
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

  group('dark theme: control and card boundaries hold 3:1', () {
    final theme = buildAppTheme(Brightness.dark);
    final surfaces = <String, Color>{
      'page': theme.scaffoldBackgroundColor,
      'card': sampleDarkCard,
      'scenario card': sampleDarkPrimaryLow,
      'elevated surface': sampleDarkElevated,
      'hover surface': sampleDarkHover,
    };

    test('unfocused text fields keep a visible two-pixel dark outline', () {
      expect(theme.inputDecorationTheme.enabledBorder!.borderSide.width, 2);
    });

    test('preset and segmented outlines clear 3:1 on adjacent fills', () {
      for (final side in [
        _outlinedButtonSide(Brightness.dark),
        _segmentSide(Brightness.dark),
        _segmentSide(Brightness.dark, {WidgetState.selected}),
        _chipSide(Brightness.dark, <WidgetState>{})!.color,
      ]) {
        for (final entry in {
          ...surfaces,
          'selected segment': sampleDarkAccentContainer,
        }.entries) {
          expect(
            _contrast(Color.alphaBlend(side, entry.value), entry.value),
            greaterThanOrEqualTo(3.0),
            reason: 'control outline on ${entry.key}',
          );
        }
      }
    });

    test('card borders clear 3:1 on their inside and outside surfaces', () {
      for (final border in [
        sampleBorderFor(Brightness.dark),
        sampleScenarioBorderFor(Brightness.dark),
      ]) {
        for (final entry in surfaces.entries) {
          expect(
            _contrast(Color.alphaBlend(border, entry.value), entry.value),
            greaterThanOrEqualTo(3.0),
            reason: 'card border against ${entry.key}',
          );
        }
      }
    });

    testWidgets('rendered scenario frames and preset use the contrast roles', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SampleScenarioBlock(
                    title: 'Try it',
                    child: SamplePanel(
                      child: Column(
                        children: [
                          SamplePillButton(
                            secondary: true,
                            onPressed: () {},
                            child: const Text('Preset'),
                          ),
                          SampleSegmentedChoice<int>(
                            options: const [(0, 'First'), (1, 'Second')],
                            selected: 0,
                            onChanged: (_) {},
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SampleSection(title: 'Live state', child: Text('Idle')),
                ],
              ),
            ),
          ),
        ),
      );
      for (final type in [SampleScenarioBlock, SamplePanel, SampleSection]) {
        final frame = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(type),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Container && widget.decoration is BoxDecoration,
                ),
              )
              .first,
        );
        final decoration = frame.decoration! as BoxDecoration;
        final side = (decoration.border! as Border).top;
        expect(side.width, greaterThanOrEqualTo(2));
        for (final adjacent in [
          decoration.color!,
          type == SamplePanel
              ? sampleDarkPrimaryLow
              : theme.scaffoldBackgroundColor,
        ]) {
          expect(
            _contrast(Color.alphaBlend(side.color, adjacent), adjacent),
            greaterThanOrEqualTo(3.0),
            reason: '$type frame against $adjacent',
          );
        }
      }
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(OutlinedButton),
          matching: find.byType(Material),
        ),
      );
      final side = (material.shape! as OutlinedBorder).side;
      expect(side.width, greaterThanOrEqualTo(2));
      expect(
        _contrast(side.color, sampleDarkPrimaryLow),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        theme.segmentedButtonTheme.style!.side!.resolve({})!.width,
        greaterThanOrEqualTo(2),
      );
      expect(tester.takeException(), isNull);
    });

    test('an unselected chip draws the dark control outline', () {
      expect(
        _chipSide(Brightness.dark, <WidgetState>{})?.color,
        sampleDarkControlOutline,
      );
    });

    test('a selected chip has no outline', () {
      final side = _chipSide(Brightness.dark, <WidgetState>{
        WidgetState.selected,
      });
      expect(side?.color, Colors.transparent);
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
