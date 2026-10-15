import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:octopus_sdk_flutter_example/app_log.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/config/config_screen.dart';
import 'package:octopus_sdk_flutter_example/debug/debug_log.dart';
import 'package:octopus_sdk_flutter_example/settings/appearance_screen.dart';
import 'package:octopus_sdk_flutter_example/settings/language_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/method_channel_shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('octopus_sdk_flutter');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> pump(WidgetTester tester, AppState app, Widget page) async {
    await tester.pumpWidget(
      AppScope(
        state: app,
        child: MaterialApp(home: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Language saves before initialize and applies after starting', (
    tester,
  ) async {
    final app = AppState();
    addTearDown(app.dispose);
    final oldLog = demoLog;
    final log = RealDebugLog();
    demoLog = log;
    addTearDown(() {
      demoLog = oldLog;
      log.dispose();
    });
    expect(app.config, isNull);
    await pump(tester, app, const LanguageScreen());
    await tester.tap(find.text('French'));
    await tester.pumpAndSettle();
    expect(app.localeTag, 'fr');
    expect(
      calls.where((call) => call.method == 'overrideDefaultLocale'),
      isEmpty,
    );
    expect(log.exportText(), isNot(contains('overrideDefaultLocale')));
    await app.setLocaleTag('de');
    expect(log.exportText(), isNot(contains('overrideDefaultLocale')));
    await app.setLocale(LocaleChoice.fr);
    expect(
      (await SharedPreferences.getInstance()).getString(sdkLocalePreferenceKey),
      'fr',
    );
    await app.start(
      app.configurationChoices.copyWith(
        apiKeySource: ApiKeySource.custom,
        customApiKey: 'fixture-only',
      ),
    );
    expect(app.initialized, isTrue);
    final methods = calls.map((call) => call.method).toList();
    expect(
      methods.indexOf('initialize'),
      lessThan(methods.indexOf('overrideDefaultLocale')),
    );
    expect(
      calls
          .firstWhere((call) => call.method == 'overrideDefaultLocale')
          .arguments['languageCode'],
      'fr',
    );
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Appearance with no config is editable and persists the SDK theme',
    (tester) async {
      final app = AppState();
      addTearDown(app.dispose);
      await pump(tester, app, const AppearanceScreen());
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SDK default'));
      await tester.pumpAndSettle();
      expect(app.initialized, isFalse);
      expect(calls, isEmpty);
      final saved = await loadPersistedDemoConfig();
      expect(saved!.theme, AppThemeChoice.dark);
      expect(saved.octopusNavyTheme, isFalse);
      await app.start(
        app.configurationChoices.copyWith(
          apiKeySource: ApiKeySource.custom,
          customApiKey: 'fixture-only',
        ),
      );
      expect(app.effectiveOctopusTheme()!.themeMode, OctopusThemeMode.dark);
      expect(app.activeThemeLabel, 'SDK default');
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Configuration is collapsed in Android section order', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ConfigScreen()));
    final sections = tester
        .widgetList<ExpansionTile>(find.byType(ExpansionTile))
        .toList();
    expect(sections.map((section) => (section.title as Text).data), [
      'Server environment',
      'Community',
      'Connect your users (SSO)',
      'Theme',
    ]);
    expect(sections.every((section) => !section.initiallyExpanded), isTrue);
  });

  test('build-injected demo host keeps its host and Demo label', () {
    final config = buildInitialDemoConfig(
      host: 'demo.example.test',
      userId: 'fixture',
    );
    expect(config.serverEnv, ServerEnv.demo);
    expect(config.resolvedHost, 'demo.example.test');
    expect(config.apiServer!.host, 'demo.example.test');
    expect(
      buildInitialDemoConfig(host: '', userId: 'fixture').apiServer,
      isNull,
    );
  });

  for (final host in ['build.example.test', '', 'api.8pus.io']) {
    test('Demo ignores a custom endpoint with build host "$host"', () {
      final config = buildInitialDemoConfig(host: host, userId: 'fixture')
          .copyWith(
            serverEnv: ServerEnv.demo,
            customHost: 'stale.example.test',
            customPort: 8443,
          );
      expect(config.resolvedHost, host);
      expect(config.apiServer?.host, host.isEmpty ? null : host);
      expect(config.apiServer?.port, host.isEmpty ? null : 443);
      expect(config.toJson()['customHost'], isEmpty);
      expect(config.pointsAtProduction, host.isEmpty || host == 'api.8pus.io');
    });
  }

  for (final failure in ['false', 'exception', 'read']) {
    test('language and Reset survive preference $failure failures', () async {
      const prefsChannel = MethodChannel(
        'plugins.flutter.io/shared_preferences',
      );
      final oldStore = SharedPreferencesStorePlatform.instance;
      final oldLog = demoLog;
      final log = RealDebugLog();
      demoLog = log;
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance =
          MethodChannelSharedPreferencesStore();
      addTearDown(() {
        messenger.setMockMethodCallHandler(prefsChannel, null);
        SharedPreferences.resetStatic();
        SharedPreferencesStorePlatform.instance = oldStore;
        demoLog = oldLog;
        log.dispose();
      });
      final removals = <String>[];
      messenger.setMockMethodCallHandler(prefsChannel, (call) async {
        if (call.method == 'getAll') {
          if (failure == 'read') {
            throw PlatformException(code: 'unavailable');
          }
          return <String, Object>{};
        }
        if (call.method == 'remove') {
          removals.add(call.arguments['key'] as String);
        }
        if (failure == 'exception') {
          throw PlatformException(code: 'unavailable');
        }
        return false;
      });
      final app = AppState();
      addTearDown(app.dispose);
      var notifications = 0;
      app.addListener(() => notifications++);
      await app.setLocaleTag('de');
      expect(app.localeTag, 'de');
      expect(log.exportText(), contains('Language preference'));
      expect(log.exportText(), isNot(contains('overrideDefaultLocale')));
      await app.reset();
      expect(app.localeTag, isEmpty);
      expect(app.config, isNull);
      expect(app.hostProfileEditWired, isTrue);
      expect(notifications, 2);
      expect(log.exportText(), contains('Preference'));
      if (failure != 'false') {
        expect(log.exportText(), contains('PlatformException(unavailable'));
      }
      if (failure != 'read') expect(removals, hasLength(4));
      await app.restoreSdkLocale();
    });
  }

  test(
    'Android enables four host callbacks with profile navigation off',
    () async {
      final app = AppState();
      addTearDown(app.dispose);
      expect(app.unifiedProfileWired, isFalse);
      expect([
        app.hostProfileEditWired,
        app.hostGroupAccessWired,
        app.onAuthenticationRequiredWired,
        app.onNavigateToContentWired,
      ], everyElement(isTrue));
      app.setUnifiedProfileWired(true);
      await app.reset();
      expect(app.unifiedProfileWired, isFalse);
    },
  );

  test(
    'malformed host preferences are dropped atomically and notify the UI',
    () async {
      SharedPreferences.setMockInitialValues({
        'host_integration_v1': '{"profile":true,"edit":false,"url":42}',
      });
      final app = AppState();
      addTearDown(app.dispose);
      var changes = 0;
      app.addListener(() => changes++);
      await app.restoreHostIntegration();
      expect(changes, 1);
      expect(app.unifiedProfileWired, isFalse);
      expect(app.hostProfileEditWired, isTrue);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'host_integration_v1',
        ),
        isNull,
      );
    },
  );

  for (final failure in ['false', 'exception']) {
    test(
      'host preference save $failure is logged without an unhandled error',
      () async {
        const prefsChannel = MethodChannel(
          'plugins.flutter.io/shared_preferences',
        );
        final oldStore = SharedPreferencesStorePlatform.instance;
        final oldLog = demoLog;
        final log = RealDebugLog();
        demoLog = log;
        SharedPreferences.resetStatic();
        SharedPreferencesStorePlatform.instance =
            MethodChannelSharedPreferencesStore();
        addTearDown(() {
          messenger.setMockMethodCallHandler(prefsChannel, null);
          SharedPreferences.resetStatic();
          SharedPreferencesStorePlatform.instance = oldStore;
          demoLog = oldLog;
          log.dispose();
        });
        final save = Completer<void>();
        messenger.setMockMethodCallHandler(prefsChannel, (call) async {
          if (call.method == 'getAll') return <String, Object>{};
          if (call.method == 'setString') {
            save.complete();
            if (failure == 'exception') {
              throw PlatformException(code: 'unavailable');
            }
            return false;
          }
          return true;
        });
        final app = AppState();
        addTearDown(app.dispose);
        app.setHostProfileEditWired(false);
        await save.future;
        await Future<void>.delayed(Duration.zero);
        expect(app.hostProfileEditWired, isFalse);
        expect(
          log.exportText(),
          contains(failure == 'false' ? 'could not be saved' : 'save failed'),
        );
      },
    );
  }
}
