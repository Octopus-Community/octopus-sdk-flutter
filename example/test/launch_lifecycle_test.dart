import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/config/config_screen.dart';
import 'package:octopus_sdk_flutter_example/feature_toggles.dart';
import 'package:octopus_sdk_flutter_example/main.dart';
import 'package:octopus_sdk_flutter_example/sample_tab.dart';
import 'package:octopus_sdk_flutter_example/scenarios/live_community_config_card.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sample_shell_test.dart' show pumpShell, selectTab;

const _configured = DemoConfig(
  apiKeySource: ApiKeySource.custom,
  customApiKey: 'fixture-only',
  userId: 'saved-user',
  theme: AppThemeChoice.dark,
  serverEnv: ServerEnv.custom,
  customHost: 'demo.example.test',
  octopusNavyTheme: false,
  featureToggles: FeatureToggles(forceLogin: true, pushRegistration: false),
);

class _Sdk extends OctopusSDK {
  @override
  Future<OctopusDebugCommunityConfig> debugGetCommunityConfig() async =>
      const OctopusDebugCommunityConfig(
        exposeClientUserId: true,
        forceLoginOnStrongActions: true,
        displayAccountAge: true,
      );
}

class _App extends AppState {
  final sdk = _Sdk();
  @override
  OctopusSDK get octopus => sdk;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    calls.clear();
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Sample',
      packageName: 'sample',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    messenger.setMockStreamHandler(
      const EventChannel('octopus_sdk_flutter/events'),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('octopus_sdk_flutter'),
      (call) async {
        calls.add(call);
        return null;
      },
    );
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(
      const MethodChannel('octopus_sdk_flutter'),
      null,
    );
  });

  test('explicit prod build initializes on two consecutive launches', () async {
    SharedPreferences.setMockInitialValues({
      demoConfigPrefsKey: jsonEncode(_configured.toJson()),
    });
    final build =
        buildInitialDemoConfig(
          host: 'api.8pus.io',
          userId: 'build-user',
        ).copyWith(
          apiKeySource: ApiKeySource.custom,
          customApiKey: 'fixture-build',
        );
    for (var launch = 0; launch < 2; launch++) {
      final app = AppState(buildConfig: build);
      await app.bootstrap();
      expect(app.initialized, isTrue, reason: 'launch ${launch + 1}');
      expect(app.config!.userId, 'build-user');
      expect(app.config!.resolvedHost, 'api.8pus.io');
      // Let start's asynchronous persistence complete before the next launch.
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(demoConfigPrefsKey), isNotNull);
      expect(
        prefs.getString(demoConfigPrefsKey),
        isNot(contains('fixture-build')),
      );
      await app.stopForScenario();
      app.dispose();
    }
    final initializations = calls.where((call) => call.method == 'initialize');
    expect(initializations, hasLength(2));
    for (final call in initializations) {
      final arguments = call.arguments as Map;
      expect(arguments['apiKey'], 'fixture-build');
      expect((arguments['apiServer'] as Map)['host'], 'api.8pus.io');
    }
  });

  test(
    'Custom to Demo initializes and switches on the current build host',
    () async {
      final build = buildInitialDemoConfig(
        host: 'build.example.test',
        userId: 'fixture',
      );
      final app = AppState(buildConfig: build);
      addTearDown(app.dispose);
      final demo = _configured.copyWith(
        serverEnv: ServerEnv.demo,
        customPort: 8443,
      );
      await app.start(demo);
      await app.start(_configured);
      await app.start(demo);
      final targets = calls
          .where(
            (call) =>
                call.method == 'initialize' || call.method == 'switchCommunity',
          )
          .toList();
      expect(targets, hasLength(3));
      expect(
        (targets.first.arguments['apiServer'] as Map)['host'],
        'build.example.test',
      );
      expect(
        (targets[1].arguments['apiServer'] as Map)['host'],
        _configured.customHost,
      );
      expect(
        (targets.last.arguments['apiServer'] as Map)['host'],
        'build.example.test',
      );
      expect((targets.last.arguments['apiServer'] as Map)['port'], 443);
      expect(
        (await loadPersistedDemoConfig(
          buildHost: build.buildHost,
        ))!.resolvedHost,
        'build.example.test',
      );
      await app.stopForScenario();
    },
  );

  test(
    'bootstrap restores Demo using the new build, retaining its choices',
    () async {
      final saved = _configured.copyWith(serverEnv: ServerEnv.demo).toJson()
        ..['customHost'] = 'previous-build.example.test';
      SharedPreferences.setMockInitialValues({
        demoConfigPrefsKey: jsonEncode(saved),
      });
      final app = AppState(
        buildConfig: buildInitialDemoConfig(
          host: 'new-build.example.test',
          userId: 'build-user',
        ),
      );
      addTearDown(app.dispose);
      await app.bootstrap();
      expect(app.config!.serverEnv, ServerEnv.demo);
      expect(app.config!.resolvedHost, 'new-build.example.test');
      expect(app.config!.userId, _configured.userId);
      expect(app.config!.theme, _configured.theme);
      expect(app.initialized, isFalse);
      expect(calls.where((call) => call.method == 'initialize'), isEmpty);
    },
  );

  // Bootstrap loads assets outside the widget test's fake clock. Construct
  // its async queues in the same real zone used to await them.
  Future<AppState> bootstrapApp(
    WidgetTester tester, {
    DemoConfig? config,
  }) async {
    return (await tester.runAsync(() async {
      final app = AppState(buildConfig: config);
      await app.bootstrap();
      return app;
    }))!;
  }

  testWidgets('pasted-key relaunch keeps choices in both Config entry points', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      demoConfigPrefsKey: jsonEncode(_configured.toJson()),
    });
    final app = await bootstrapApp(tester);
    expect(app.initialized, isFalse);
    expect(calls.where((call) => call.method == 'initialize'), isEmpty);
    final config = app.config!;
    expect(config.customApiKey, isEmpty);
    expect(config.userId, _configured.userId);
    expect(config.theme, _configured.theme);
    expect(config.customHost, _configured.customHost);
    expect(config.octopusNavyTheme, isFalse);
    expect(config.featureToggles, _configured.featureToggles);

    await pumpShell(tester, state: app);
    await selectTab(tester, SampleTab.settings);
    final entry = find.text('Configuration');
    await tester.scrollUntilVisible(
      entry,
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(
      tester.widget<ConfigScreen>(find.byType(ConfigScreen)).initialConfig,
      same(config),
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    unawaited(openConfigScreen(tester.element(find.byType(MainScreen))));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ConfigScreen>(find.byType(ConfigScreen)).initialConfig,
      same(config),
    );
  });

  testWidgets('keyless launch switches work and persist their choices', (
    tester,
  ) async {
    final app = await bootstrapApp(
      tester,
      config: const DemoConfig(
        apiKeySource: ApiKeySource.custom,
        userId: 'keyless-user',
        theme: AppThemeChoice.system,
        serverEnv: ServerEnv.prod,
      ),
    );
    expect(app.config, isNotNull);
    expect(app.initialized, isFalse);
    await pumpShell(tester, state: app);
    final toggle = find.bySemanticsIdentifier(FeatureToggle.forceLogin.testId);
    await tester.scrollUntilVisible(
      toggle,
      160,
      scrollable: find.byType(Scrollable).last,
    );
    final control = find.descendant(of: toggle, matching: find.byType(Switch));
    expect(tester.widget<Switch>(control).onChanged, isNotNull);
    await tester.tap(control);
    await tester.pumpAndSettle();
    expect(app.featureToggles.forceLogin, isTrue);
    expect(
      (await loadPersistedDemoConfig())!.featureToggles.forceLogin,
      isTrue,
    );
    expect(calls.where((call) => call.method == 'initialize'), isEmpty);
  });

  testWidgets('reset disables switches with an explanation', (tester) async {
    final app = await bootstrapApp(tester);
    await tester.runAsync(app.reset);
    await pumpShell(tester, state: app);
    final toggle = find.bySemanticsIdentifier(FeatureToggle.forceLogin.testId);
    await tester.scrollUntilVisible(
      toggle,
      160,
      scrollable: find.byType(Scrollable).last,
    );
    final control = find.descendant(of: toggle, matching: find.byType(Switch));
    expect(tester.widget<Switch>(control).onChanged, isNull);
    expect(
      find.text('Configure the SDK in Settings to enable this switch.'),
      findsWidgets,
    );
  });

  testWidgets('stopped live config points to Restart and hides its old key', (
    tester,
  ) async {
    final app = _App();
    addTearDown(app.dispose);
    await app.start(_configured);
    await tester.pumpWidget(
      AppScope(
        state: app,
        child: const MaterialApp(
          home: Scaffold(body: LiveCommunityConfigCard(active: true)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('••••'), findsOneWidget);
    await app.stopForScenario();
    await tester.pump();
    expect(find.text('SDK stopped — use Restart the SDK'), findsOneWidget);
    expect(find.text('••••'), findsNothing);
    expect(find.text('✓ on'), findsNothing);
    expect(app.activeApiKey, _configured.customApiKey);
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'Restart while running stops then initializes the live target',
    () async {
      final app = AppState();
      addTearDown(app.dispose);
      await app.start(_configured);
      await app.switchToCommunity('fixture-switched');
      calls.clear();
      await app.restartForScenario();
      expect(
        calls
            .where(
              (call) => const [
                'stop',
                'initialize',
                'switchCommunity',
              ].contains(call.method),
            )
            .map((call) => call.method),
        ['stop', 'initialize'],
      );
      final arguments =
          calls.firstWhere((call) => call.method == 'initialize').arguments
              as Map;
      expect(arguments['apiKey'], 'fixture-switched');
      expect((arguments['apiServer'] as Map)['host'], _configured.customHost);
      expect(app.initialized, isTrue);
      expect(app.stopped, isFalse);
      await app.stopForScenario();
    },
  );
}
