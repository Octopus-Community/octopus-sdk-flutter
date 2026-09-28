import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/branding.dart';
import 'package:octopus_sdk_flutter_example/design.dart';

Future<void> _pump(WidgetTester tester, Brightness brightness, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(brightness),
      home: Scaffold(body: child),
    ),
  );
}

Color? _textColor(WidgetTester tester, String text) {
  return tester.widget<Text>(find.text(text)).style?.color;
}

const _summary = SampleSection(
  title: 'Current configuration',
  child: Column(
    children: [
      SampleKeyValue('Server environment', 'Demo'),
      SampleKeyValue('Host', 'demo.example', mono: true),
    ],
  ),
);

const _content = SampleDockFade(child: SizedBox.expand());

Finder get _mask => find.descendant(
  of: find.byType(SampleDockFade),
  matching: find.byType(ShaderMask),
);

void main() {
  testWidgets('dark: summary card title, labels and values', (tester) async {
    await _pump(tester, Brightness.dark, _summary);

    expect(_textColor(tester, 'Current configuration'), sampleDarkText);
    expect(_textColor(tester, 'Server environment'), sampleDarkSecondary);
    expect(_textColor(tester, 'Host'), sampleDarkSecondary);
    expect(_textColor(tester, 'Demo'), sampleDarkBody);
    expect(_textColor(tester, 'demo.example'), sampleDarkBody);
  });

  testWidgets('light: the summary card keeps its navy title', (tester) async {
    await _pump(tester, Brightness.light, _summary);

    expect(_textColor(tester, 'Current configuration'), sampleNavy);
  });

  testWidgets('dark: the content above the dock fades out as a mask', (
    tester,
  ) async {
    await _pump(tester, Brightness.dark, _content);

    expect(_mask, findsOneWidget);
    // A mask keeps what the content covers and drops the rest: whatever is
    // behind — page colour or halo — shows through, with no colour of its own.
    expect(tester.widget<ShaderMask>(_mask).blendMode, BlendMode.dstIn);
  });

  test('the dock fade mask: opaque, then transparent over the last 24dp', () {
    final mask = SampleDockFade.maskFor(const Size(400, 600));
    expect(mask.colors.map((c) => c.a), [1, 1, 0]);
    expect(mask.stops, [0, 1 - SampleDockFade.height / 600, 1]);
    // Shorter than the fade: fades over the whole height, never a negative stop.
    expect(SampleDockFade.maskFor(const Size(400, 10)).stops, [0, 0, 1]);
  });

  testWidgets('light: the content is the child alone', (tester) async {
    await _pump(tester, Brightness.light, _content);

    expect(_mask, findsNothing);
  });
}
