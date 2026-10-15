import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/scenarios/community_data_scenario.dart';
import 'package:octopus_sdk_flutter_example/scenarios/scenarios_screen.dart';
import 'package:octopus_sdk_flutter_example/scenarios/unified_profile_scenario.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scenarios → Sign-in & user → "Unified Profile (exposeClientUserId)" override.
void main() {
  test('each choice maps to the value handed to the SDK', () {
    expect(ExposeClientUserIdOverride.backend.enabled, isNull);
    expect(ExposeClientUserIdOverride.forceOn.enabled, isTrue);
  });

  test('labels and test ids are the Android sample\'s, in order', () {
    expect(ExposeClientUserIdOverride.values.map((c) => c.label), [
      'Use backend value',
      'Force active',
    ]);
    expect(ExposeClientUserIdOverride.values.map((c) => c.testId), [
      'expose-override-backend',
      'expose-override-on',
    ]);
  });

  test('the host leaves onNavigateToProfile off by default, like Android', () {
    expect(AppState().unifiedProfileWired, isFalse);
  });

  test('a fresh state keeps the backend value and applies nothing', () async {
    final app = AppState();
    expect(app.exposeClientUserIdOverride, ExposeClientUserIdOverride.backend);
    // Not initialized: the choice is recorded, no platform call is made (a
    // call would throw MissingPluginException in a host-side test).
    await app.setExposeClientUserIdOverride(ExposeClientUserIdOverride.forceOn);
    expect(app.exposeClientUserIdOverride, ExposeClientUserIdOverride.forceOn);
    expect(app.communityConfig, isNull);
    expect(app.exposeClientUserIdSummary, 'unknown · Force active');
  });

  for (final backendFlag in [true, false]) {
    testWidgets(
      'Unified Profile switch forces ON and restores backend=$backendFlag on OFF',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 3000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        const channel = MethodChannel('octopus_sdk_flutter');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final overrides = <bool?>[];
        bool? forcedFlag;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'debugOverrideExposeClientUserId') {
            forcedFlag = call.arguments['enabled'] as bool?;
            overrides.add(forcedFlag);
          }
          if (call.method == 'debugGetCommunityConfig') {
            return {'exposeClientUserId': forcedFlag ?? backendFlag};
          }
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final app = AppState();
        addTearDown(app.dispose);
        await app.start(
          app.configurationChoices.copyWith(
            apiKeySource: ApiKeySource.custom,
            customApiKey: 'fixture-only',
          ),
        );
        expect(app.initialized, isTrue);
        overrides.clear();
        await tester.pumpWidget(
          AppScope(
            state: app,
            child: const MaterialApp(home: UnifiedProfileScenario()),
          ),
        );
        await tester.pumpAndSettle();
        final toggle = find.byType(SwitchListTile);
        expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(app.unifiedProfileWired, isTrue);
        expect(
          app.exposeClientUserIdOverride,
          ExposeClientUserIdOverride.forceOn,
        );
        expect(app.communityConfig!.exposeClientUserId, isTrue);
        expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(app.unifiedProfileWired, isFalse);
        expect(
          app.exposeClientUserIdOverride,
          ExposeClientUserIdOverride.backend,
        );
        expect(app.communityConfig!.exposeClientUserId, backendFlag);
        expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
        expect(find.text('Profile taps open native profiles'), findsOneWidget);
        expect(overrides, [true, null]);

        // OFF keeps the backend value after targeting another community.
        await app.switchToCommunity('another-fixture');
        await tester.pumpAndSettle();
        expect(overrides, [true, null, null]);
        expect(app.communityConfig!.exposeClientUserId, backendFlag);

        // QA can force the flag independently without wiring the callback,
        // then restore the backend value again.
        await tester.tap(find.text('Backend flag override'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsIdentifier('expose-override-on'));
        await tester.pumpAndSettle();
        expect(app.communityConfig!.exposeClientUserId, isTrue);
        expect(app.unifiedProfileWired, isFalse);
        expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
        await tester.tap(find.bySemanticsIdentifier('expose-override-backend'));
        await tester.pumpAndSettle();
        expect(overrides, [true, null, null, true, null]);
        expect(
          app.exposeClientUserIdOverride,
          ExposeClientUserIdOverride.backend,
        );
        expect(app.communityConfig!.exposeClientUserId, backendFlag);
        expect(app.unifiedProfileWired, isFalse);
      },
    );
  }

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
        matching: find.textContaining('unknown · Use backend value'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'Unified Profile opens a detail route with an independent flag override',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = AppState();
      addTearDown(app.dispose);
      await tester.pumpWidget(
        AppScope(
          state: app,
          child: const MaterialApp(home: Scaffold(body: ScenariosTab())),
        ),
      );
      await tester.tap(find.bySemanticsIdentifier('scenarios-section-sso'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.bySemanticsIdentifier('scenarios-unifiedProfile-card'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.text('Try it'), findsOneWidget);
      expect(find.text('Force login is off'), findsOneWidget);
      expect(find.bySemanticsIdentifier('expose-override-on'), findsNothing);
      await tester.tap(find.text('Backend flag override'));
      await tester.pumpAndSettle();
      for (final choice in ExposeClientUserIdOverride.values) {
        expect(find.bySemanticsIdentifier(choice.testId), findsOneWidget);
      }
      await tester.tap(find.text('Force flag on'));
      await tester.pumpAndSettle();
      expect(
        app.exposeClientUserIdOverride,
        ExposeClientUserIdOverride.forceOn,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsIdentifier('scenario-detail-screen'),
        findsNothing,
      );
      await tester.enterText(find.byType(TextField), 'profile');
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsIdentifier('scenarios-unifiedProfile-card'),
        findsOneWidget,
      );
    },
  );
}
