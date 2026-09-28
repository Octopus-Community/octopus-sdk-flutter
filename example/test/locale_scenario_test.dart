import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/scenarios/locale_scenario.dart';

/// The Locale scenario must report — and show — the override it actually
/// applied. Tapping "Force fr" from a freshly mounted screen used to run the
/// *reset* preset, because the run was resolved by matching the preset values
/// against the spec built on the previous frame, where the field was still
/// blank (`#355`).
void main() {
  const channel = MethodChannel('octopus_sdk_flutter');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('"Force fr" reports and shows the fr override, not a reset', (
    tester,
  ) async {
    // The scenario frame is a scrolling column: the default 800x600 viewport
    // never builds the presets or the result panel below the fold.
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        state: AppState(),
        child: const MaterialApp(home: LocaleScenario()),
      ),
    );
    await tester.pump();

    // The mount state the defect needed: no override applied, so the locale
    // field is blank — which is preset 3's ("Reset to system") own value.
    expect(find.text('System'), findsOneWidget);

    await tester.tap(find.bySemanticsIdentifier('qa-preset-locale-1'));
    await tester.pumpAndSettle();

    expect(
      calls.map((c) => c.arguments['languageCode']).toList(),
      ['fr'],
      reason: 'the Force fr preset sends fr to the native SDK',
    );
    expect(
      find.textContaining('Locale override → fr'),
      findsOneWidget,
      reason: 'the result line reports what ran',
    );
    expect(find.text('Locale override reset to system default.'), findsNothing);
    // Live state, the second half of the defect: "System" while the SDK
    // renders French is the one read-out worth never shipping.
    expect(find.text('fr'), findsWidgets);
    expect(find.text('System'), findsNothing);
  });
}
