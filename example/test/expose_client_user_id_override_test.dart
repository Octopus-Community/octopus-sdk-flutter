import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/scenarios/community_data_scenario.dart';

/// Config → Integration's "Unified Profile (exposeClientUserId)" tri-state.
void main() {
  test('each choice maps to the value handed to the SDK', () {
    expect(ExposeClientUserIdOverride.backend.enabled, isNull);
    expect(ExposeClientUserIdOverride.forceOn.enabled, isTrue);
    expect(ExposeClientUserIdOverride.forceOff.enabled, isFalse);
  });

  test('labels are the three Config segments, in order', () {
    expect(ExposeClientUserIdOverride.values.map((c) => c.label), [
      'Backend',
      'Force on',
      'Force off',
    ]);
  });

  test('a fresh state keeps the backend value and applies nothing', () async {
    final app = AppState();
    expect(app.exposeClientUserIdOverride, ExposeClientUserIdOverride.backend);
    // Not initialized: the choice is recorded, no platform call is made (a
    // call would throw MissingPluginException in a host-side test).
    await app.setExposeClientUserIdOverride(ExposeClientUserIdOverride.forceOn);
    expect(app.exposeClientUserIdOverride, ExposeClientUserIdOverride.forceOn);
    expect(app.communityConfig, isNull);
    expect(app.exposeClientUserIdSummary, 'unknown · Force on');
  });

  testWidgets('the Community Data scenario shows the flag hint', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        state: AppState(),
        child: const MaterialApp(home: CommunityDataScenario()),
      ),
    );
    await tester.pump();

    final hint = find.bySemanticsIdentifier(
      'communityData-exposeClientUserId-hint',
    );
    expect(hint, findsOneWidget);
    expect(
      find.descendant(
        of: hint,
        matching: find.textContaining('unknown · Backend'),
      ),
      findsOneWidget,
    );
  });
}
