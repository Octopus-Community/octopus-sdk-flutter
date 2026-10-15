import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/branding.dart';
import 'package:octopus_sdk_flutter_example/design.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x < y ? x : y) + .05);
}

void main() {
  for (final brightness in Brightness.values) {
    final theme = buildAppTheme(brightness);
    final c = theme.colorScheme;
    final dark = brightness == Brightness.dark;
    test('$brightness control indicator meets non-text 3:1', () {
      expect(
        contrast(
          sampleOnControlAccent(brightness),
          sampleControlAccent(brightness),
        ),
        greaterThanOrEqualTo(3),
      );
    });
    test('$brightness snackbar content and action meet text 4.5:1', () {
      final snackbar = theme.snackBarTheme;
      for (final ink in [
        snackbar.contentTextStyle!.color!,
        snackbar.actionTextColor!,
      ]) {
        expect(
          contrast(ink, snackbar.backgroundColor!),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
    test('$brightness text roles meet 4.5:1', () {
      final surfaces = [
        theme.scaffoldBackgroundColor,
        c.surface,
        c.surfaceContainerHighest,
        c.surfaceBright,
      ];
      final ink = [
        c.onSurface,
        c.onSurfaceVariant,
        sampleAccent(brightness),
        sampleDangerFor(brightness),
      ];
      final pairs = <(Color, Color)>[
        for (final bg in surfaces)
          for (final text in ink) (text, bg),
        (c.onPrimary, c.primary),
        (c.onSecondary, c.secondary),
        (c.onPrimaryContainer, c.primaryContainer),
        (c.onError, c.error),
        (c.onErrorContainer, c.errorContainer),
        (
          sampleGreenFor(brightness),
          dark ? sampleDarkGreenTint : sampleGreenTint,
        ),
        (
          sampleAmberFor(brightness),
          dark ? sampleDarkAmberTint : sampleAmberTint,
        ),
        (sampleGreenFor(brightness), c.surface),
        (sampleAmberFor(brightness), c.surface),
        (sampleCodeText, dark ? sampleDarkCodeSurface : sampleCodeSurface),
      ];
      for (final (fg, bg) in pairs) {
        expect(
          contrast(fg, bg),
          greaterThanOrEqualTo(4.5),
          reason: '$fg on $bg',
        );
      }
    });
    testWidgets('$brightness links use AA ink on the page and a card', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Column(
              children: [
                SampleLink(label: 'Configure', onTap: () {}),
                SampleSection(
                  title: 'Actions',
                  child: SampleLink(label: 'Account', onTap: () {}),
                ),
              ],
            ),
          ),
        ),
      );
      for (final button in tester.widgetList<TextButton>(
        find.byType(TextButton),
      )) {
        final ink = button.style!.foregroundColor!.resolve({})!;
        expect(ink, sampleAccent(brightness));
        for (final surface in [theme.scaffoldBackgroundColor, c.surface]) {
          expect(contrast(ink, surface), greaterThanOrEqualTo(4.5));
        }
      }
    });
    testWidgets('$brightness focused field label uses AA ink', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: TextField(decoration: InputDecoration(labelText: 'Nickname')),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      final label = tester.element(find.text('Nickname'));
      final ink = DefaultTextStyle.of(
        label,
      ).style.merge((label.widget as Text).style).color!;
      expect(ink, sampleAccent(brightness));
      expect(contrast(ink, c.surface), greaterThanOrEqualTo(4.5));
      final styles = theme.inputDecorationTheme;
      for (final style in [styles.labelStyle!, styles.floatingLabelStyle!]) {
        expect(
          WidgetStateProperty.resolveAs<TextStyle>(style, {
            WidgetState.error,
          }).color,
          c.error,
        );
        expect(
          WidgetStateProperty.resolveAs<TextStyle>(style, {
            WidgetState.disabled,
          }).color,
          c.onSurfaceVariant,
        );
      }
    });
    testWidgets('$brightness danger buttons use a danger outline', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) => Scaffold(
              body: OutlinedButton(
                style: sampleDangerButtonStyle(context),
                onPressed: () {},
                child: const Text('Reset'),
              ),
            ),
          ),
        ),
      );
      final style = tester
          .widget<OutlinedButton>(find.byType(OutlinedButton))
          .style!;
      final side = style.side!.resolve({})!;
      expect(side.color, sampleDangerFor(brightness));
      expect(contrast(side.color, c.surface), greaterThanOrEqualTo(3));
      expect(contrast(side.color, c.errorContainer), greaterThanOrEqualTo(3));
    });
    test('$brightness interactive outlines meet 3:1 on each surface', () {
      for (final surface in [
        theme.scaffoldBackgroundColor,
        c.surface,
        c.surfaceContainerHighest,
        c.surfaceBright,
      ]) {
        expect(
          contrast(c.outline, surface),
          greaterThanOrEqualTo(3),
          reason: 'outline on $surface',
        );
      }
    });
    test('$brightness typography and buttons use shared tokens', () {
      for (final style in [
        theme.textTheme.bodySmall,
        theme.textTheme.labelSmall,
        theme.textTheme.bodyLarge,
      ]) {
        expect(style!.fontSize, greaterThanOrEqualTo(12));
      }
      expect(
        theme.filledButtonTheme.style!.minimumSize!.resolve({})!.height,
        SampleSize.touchMin,
      );
      expect(
        theme.textButtonTheme.style!.minimumSize!.resolve({})!.height,
        SampleSize.touchMin,
      );
    });
  }
}
