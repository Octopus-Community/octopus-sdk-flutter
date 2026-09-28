import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/branding.dart';
import 'package:octopus_sdk_flutter_example/design.dart';

Future<void> _pump(WidgetTester tester, Brightness brightness, {bool? halo}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(brightness),
      home: SampleScaffold(
        halo: halo ?? true,
        appBar: AppBar(title: const Text('Title')),
        body: const SizedBox.expand(),
      ),
    ),
  );
}

bool _isHalo(Widget w) => w is CustomPaint && w.painter != null;

Finder _inScaffold(Finder matching) =>
    find.descendant(of: find.byType(SampleScaffold), matching: matching);

Color? _appBarColor(WidgetTester tester) {
  final bar = find.descendant(
    of: find.byType(AppBar),
    matching: find.byType(Material),
  );
  return tester.widget<Material>(bar.first).color;
}

void main() {
  testWidgets('dark: halo behind a transparent app bar', (tester) async {
    await _pump(tester, Brightness.dark);

    expect(_inScaffold(find.byWidgetPredicate(_isHalo)), findsOneWidget);
    expect(_appBarColor(tester), Colors.transparent);
    final page = _inScaffold(find.byType(ColoredBox)).first;
    expect(tester.widget<ColoredBox>(page).color, sampleDarkSurface);
  });

  testWidgets('dark with the halo off: page colour only', (tester) async {
    await _pump(tester, Brightness.dark, halo: false);

    expect(_inScaffold(find.byWidgetPredicate(_isHalo)), findsNothing);
  });

  testWidgets('light: no halo, the navy app bar is kept', (tester) async {
    await _pump(tester, Brightness.light);

    expect(_inScaffold(find.byWidgetPredicate(_isHalo)), findsNothing);
    expect(_appBarColor(tester), sampleNavy);
  });

  test('the halo gradient: top-right centre, screen-width radius, fade to '
      'transparent halo colour', () {
    final painter = SampleHaloPainter(sampleDarkHalo);

    final portrait = painter.gradientFor(const Size(400, 800));
    expect(portrait.center, Alignment.topRight);
    // RadialGradient.radius is a fraction of the shorter side: here the width.
    expect(portrait.radius, 1);
    expect(portrait.colors, [
      sampleDarkHalo,
      sampleDarkHalo.withValues(alpha: 0),
    ]);

    // Landscape: the shorter side is the height, so the fraction grows to keep
    // the radius at the screen width.
    expect(painter.gradientFor(const Size(800, 400)).radius, 2);
  });

  testWidgets('dark: the halo starts at the screen top, under the status '
      'bar inset; the header clears the inset', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.dark),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            padding: EdgeInsets.only(top: 40),
          ),
          child: SampleScaffold(
            appBar: AppBar(title: const Text('Title')),
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );

    final halo = _inScaffold(find.byWidgetPredicate(_isHalo));
    expect(tester.getTopLeft(halo).dy, 0);
    expect(tester.getTopLeft(find.text('Title')).dy, greaterThanOrEqualTo(40));
  });
}
