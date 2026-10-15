import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/scenarios/content_options_scenario.dart';
import 'package:octopus_sdk_flutter_example/scenarios/force_nickname_choice_scenario.dart';
import 'package:octopus_sdk_flutter_example/scenarios/profile_fields_lock_scenario.dart';
import 'package:octopus_sdk_flutter_example/scenarios/terms_acceptance_scenario.dart';
import 'package:octopus_sdk_flutter_example/widgets/key_value_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('octopus_sdk_flutter');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  final nativeOverrides = <String, Object?>{};
  Completer<void>? pendingApply;
  String? failure;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    nativeOverrides.clear();
    pendingApply = null;
    failure = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method.startsWith('debugOverride')) {
        if (failure != null) throw PlatformException(code: failure!);
        await pendingApply?.future;
        nativeOverrides[call.method] = (call.arguments as Map).values.single;
      } else if (['switchCommunity', 'stop'].contains(call.method)) {
        nativeOverrides.clear();
      }
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  const cases =
      <
        String,
        ({
          Widget screen,
          List<String> presets,
          String method,
          String argument,
          Object value,
          String label,
          List<(String, String)> rows,
        })
      >{
        'profileFieldsLock': (
          screen: ProfileFieldsLockScenario(),
          method: 'debugOverrideProfileFieldsLock',
          argument: 'lock',
          value: {
            'nickname': 'READ_ONLY',
            'avatar': 'READ_ONLY',
            'bio': 'DISABLED',
          },
          label: 'Pseudo + avatar read-only, bio hidden',
          rows: [
            ('nickname', 'readOnly'),
            ('avatar', 'readOnly'),
            ('bio', 'disabled'),
          ],
          presets: [
            'qa-preset-profileFieldsLock-1',
            'qa-preset-profileFieldsLock-2',
            'qa-preset-profileFieldsLock-3',
            'qa-preset-profileFieldsLock-clear',
          ],
        ),
        'contentOptions': (
          screen: ContentOptionsScenario(),
          method: 'debugOverrideContentOptions',
          argument: 'options',
          value: {
            'post': {
              'enablePictures': false,
              'enablePolls': true,
              'textRequired': true,
            },
            'comment': {'enablePictures': true},
            'reply': {'enablePictures': true},
          },
          label: 'Post: pictures off',
          rows: [
            ('post.enablePictures', 'false'),
            ('post.enablePolls', 'true'),
            ('post.textRequired', 'true'),
            ('comment.enablePictures', 'true'),
            ('reply.enablePictures', 'true'),
          ],
          presets: [
            'qa-preset-contentOptions-1',
            'qa-preset-contentOptions-2',
            'qa-preset-contentOptions-3',
            'qa-preset-contentOptions-4',
            'qa-preset-contentOptions-5',
            'qa-preset-contentOptions-6',
            'qa-preset-contentOptions-7',
            'qa-preset-contentOptions-clear',
          ],
        ),
        'forceNicknameChoice': (
          screen: ForceNicknameChoiceScenario(),
          method: 'debugOverrideForceNicknameChoice',
          argument: 'enabled',
          value: false,
          label: 'Off — the generated nickname is prefilled',
          rows: [('forceNicknameChoice', 'false')],
          presets: [
            'qa-preset-forceNicknameChoice-1',
            'qa-preset-forceNicknameChoice-2',
            'qa-preset-forceNicknameChoice-clear',
          ],
        ),
        'termsAcceptance': (
          screen: TermsAcceptanceScenario(),
          method: 'debugOverrideTermsAcceptanceMode',
          argument: 'mode',
          value: 'EXPLICIT_MULTI_CHECKBOX',
          label: 'Explicit — multi checkbox',
          rows: [('TermsAcceptanceMode', 'explicitMultiCheckbox')],
          presets: [
            'qa-preset-termsAcceptance-1',
            'qa-preset-termsAcceptance-2',
            'qa-preset-termsAcceptance-3',
            'qa-preset-termsAcceptance-clear',
          ],
        ),
      };

  Future<void> mount(WidgetTester tester, AppState app, Widget screen) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      AppScope(
        state: app,
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<(String, String)> liveRows(WidgetTester tester) =>
      tester.widget<KeyValueCard>(find.byType(KeyValueCard)).rows;

  Finder result(String id, String text) => find.descendant(
    of: find.bySemanticsIdentifier('$id-result'),
    matching: find.textContaining(text),
  );

  final invalidations = <String, Future<void> Function(AppState)>{
    'community switch': (app) => app.switchToCommunity('fixture-only'),
    'scenario stop': (app) => app.stopForScenario(),
    'settings reset': (app) => app.reset(),
  };
  final preservations =
      <String, ({String method, Future<void> Function(AppState) run})>{
        'disconnect': (
          method: 'disconnectUser',
          run: (app) => app.disconnectUser(),
        ),
        'scenario reset': (
          method: 'reset',
          run: (app) => app.resetSessionForScenario(),
        ),
      };

  cases.forEach((id, spec) {
    void expectBackend(WidgetTester tester) {
      expect(liveRows(tester), [
        ('Applied override', 'none (backend default)'),
        for (final row in spec.rows) (row.$1, '— (backend)'),
      ]);
    }

    Future<void> apply(WidgetTester tester) async {
      await tester.tap(find.bySemanticsIdentifier('qa-preset-$id-2'));
      await tester.pumpAndSettle();
      expect(liveRows(tester), [
        ('Applied override', spec.label),
        ...spec.rows,
      ]);
      expect(result(id, 'Applied: ${spec.label}.'), findsOneWidget);
    }

    testWidgets('$id exposes every catalog test id on a clean mount', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final app = AppState();
      addTearDown(app.dispose);
      await mount(tester, app, spec.screen);
      for (final preset in spec.presets) {
        expect(find.bySemanticsIdentifier(preset), findsOneWidget);
      }
      expect(find.bySemanticsIdentifier('$id-result'), findsOneWidget);
      expectBackend(tester);
    });

    testWidgets('$id applies and clears the SDK override and live state', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final app = AppState();
      addTearDown(app.dispose);
      await mount(tester, app, spec.screen);
      await apply(tester);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.bySemanticsIdentifier('qa-preset-$id-clear'));
        await tester.pumpAndSettle();
        expectBackend(tester);
        expect(result(id, 'Applied: none (backend default).'), findsOneWidget);
      }
      expect(calls.map((call) => call.method), List.filled(3, spec.method));
      expect(calls.map((call) => call.arguments), [
        {spec.argument: spec.value},
        {spec.argument: null},
        {spec.argument: null},
      ]);
    });

    testWidgets('$id survives navigation within the same session', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final app = AppState();
      addTearDown(app.dispose);
      await mount(tester, app, spec.screen);
      await apply(tester);
      await mount(tester, app, const SizedBox());
      await mount(tester, app, spec.screen);
      expect(liveRows(tester), [
        ('Applied override', spec.label),
        ...spec.rows,
      ]);
      // A separate app/session must not inherit this app's applied preset.
      final freshApp = AppState();
      addTearDown(freshApp.dispose);
      await mount(tester, freshApp, spec.screen);
      expectBackend(tester);
    });

    for (final entry in preservations.entries) {
      testWidgets('$id stays in sync with native overrides on ${entry.key}', (
        tester,
      ) async {
        addTearDown(tester.view.reset);
        final app = AppState();
        addTearDown(app.dispose);
        await mount(tester, app, spec.screen);
        await apply(tester);
        final holder = app.debugScenarioOverrides;
        await entry.value.run(app);
        await tester.pumpAndSettle();
        expect(app.debugScenarioOverrides, same(holder));
        expect(nativeOverrides[spec.method], spec.value);
        expect(calls.map((call) => call.method), [
          spec.method,
          entry.value.method,
        ]);
        expect(liveRows(tester), [
          ('Applied override', spec.label),
          ...spec.rows,
        ]);
        await mount(tester, app, const SizedBox());
        await mount(tester, app, spec.screen);
        expect(liveRows(tester), [
          ('Applied override', spec.label),
          ...spec.rows,
        ]);
        expect(nativeOverrides[spec.method], spec.value);
      });
    }

    for (final entry in invalidations.entries) {
      testWidgets('$id clears on ${entry.key}, including the old result', (
        tester,
      ) async {
        addTearDown(tester.view.reset);
        final app = AppState();
        addTearDown(app.dispose);
        await mount(tester, app, spec.screen);
        await apply(tester);
        await entry.value(app);
        await tester.pumpAndSettle();
        expectBackend(tester);
        expect(result(id, 'Applied:'), findsNothing);
        // The old preset must also stay cleared when the screen is reopened.
        await mount(tester, app, const SizedBox());
        await mount(tester, app, spec.screen);
        expectBackend(tester);
      });
    }

    testWidgets('$id ignores an apply completing after session invalidation', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final app = AppState();
      addTearDown(app.dispose);
      await mount(tester, app, spec.screen);
      pendingApply = Completer<void>();
      await tester.tap(find.bySemanticsIdentifier('qa-preset-$id-2'));
      await tester.pump();
      await app.switchToCommunity('fixture-only');
      await tester.pump();
      pendingApply!.complete();
      // The disposed result scaffold still finishes its minimum spinner delay.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expectBackend(tester);
      expect(result(id, 'Applied:'), findsNothing);
    });

    testWidgets('$id retains the last successful preset when apply fails', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final app = AppState();
      addTearDown(app.dispose);
      await mount(tester, app, spec.screen);
      await apply(tester);
      failure = 'UNSUPPORTED_PLATFORM';
      await tester.tap(find.bySemanticsIdentifier('qa-preset-$id-clear'));
      await tester.pumpAndSettle();
      expect(liveRows(tester), [
        ('Applied override', spec.label),
        ...spec.rows,
      ]);
      expect(result(id, 'unavailable on this build'), findsOneWidget);
    });
  });
}
