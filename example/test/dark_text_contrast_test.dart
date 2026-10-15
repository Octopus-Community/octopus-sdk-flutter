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
}
