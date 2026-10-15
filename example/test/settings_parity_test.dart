import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/config/config_screen.dart';
import 'package:octopus_sdk_flutter_example/config/host_integration.dart';
import 'package:octopus_sdk_flutter_example/debug/debug_console.dart';
import 'package:octopus_sdk_flutter_example/debug/debug_log.dart';
import 'package:octopus_sdk_flutter_example/design.dart';
import 'package:octopus_sdk_flutter_example/feature_toggles.dart';
import 'package:octopus_sdk_flutter_example/settings/about_screen.dart';
import 'package:octopus_sdk_flutter_example/settings/appearance_screen.dart';
import 'package:octopus_sdk_flutter_example/settings/developer_tools_screen.dart';
import 'package:octopus_sdk_flutter_example/settings/debug_info_screen.dart';
import 'package:octopus_sdk_flutter_example/settings/host_integration_screen.dart';
import 'package:octopus_sdk_flutter_example/settings/language_screen.dart';
import 'package:octopus_sdk_flutter_example/settings/settings_choices.dart';
import 'package:octopus_sdk_flutter_example/settings/settings_screen.dart';
import 'package:octopus_sdk_flutter_example/sample_feedback.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:octopus_sdk_flutter_example/widgets/open_url.dart';

class _RecordingApp extends AppState {
  DemoConfig? applied;
  @override
  Future<void> start(DemoConfig config) async => applied = config;
}

class _StatusApp extends AppState {
  _StatusApp(this.connection);
  final OctopusConnectionState connection;
  @override
  bool get initialized => true;
  @override
  OctopusConnectionState get connectionState => connection;
  @override
  bool get userConnected =>
      connection is OctopusConnected &&
      !(connection as OctopusConnected).isGuest;
  @override
  bool? get hasAccess => true;
  @override
  DemoConfig get config =>
      buildInitialDemoConfig(host: 'build.example.test', userId: 'fixture');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('octopus_sdk_flutter');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    debugLog.clear();
    SharedPreferences.setMockInitialValues({});
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

  for (final (connection, status, detail) in [
    (
      const OctopusConnected(),
      'Running, signed in',
      'Every scenario is available.',
    ),
    (
      const OctopusConnected(isGuest: true),
      'Running as guest',
      'Read-only: connect an SSO user to post and react.',
    ),
    (
      const OctopusNotConnected(),
      'Started, no session',
      'The SDK has not opened a session yet, not even a guest one.',
    ),
  ]) {
    testWidgets('Settings and copied Debug info agree for $status', (
      tester,
    ) async {
      final app = _StatusApp(connection);
      addTearDown(app.dispose);
      await tester.pumpWidget(
        AppScope(
          state: app,
          child: const MaterialApp(home: Scaffold(body: SettingsTab())),
        ),
      );
      expect(find.text('Demo community'), findsOneWidget);
      expect(find.text('Demo'), findsOneWidget);
      expect(find.text('build.example.test'), findsNothing);
      expect(find.text(status), findsOneWidget);
      expect(find.text(detail), findsOneWidget);
      if (!app.userConnected) {
        expect(find.text('Not connected · sign in with SSO'), findsOneWidget);
      }
      String? copied;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final platform = SystemChannels.platform;
      messenger.setMockMethodCallHandler(platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = call.arguments['text'] as String;
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(platform, null));
      await tester.pumpWidget(
        AppScope(
          state: app,
          child: const MaterialApp(home: DebugInfoScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(status), findsOneWidget);
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(copied, contains('Status: $status'));
      expect(copied, contains('Network: Not exposed by the Flutter plugin'));
      expect(
        copied,
        contains('SDK version: Not exposed by the Flutter plugin'),
      );
      expect(copied, contains('Initialized: true'));
      expect(copied, contains('Auth mode: SSO'));
      expect(copied, contains('Community access: Granted'));
      expect(
        copied,
        contains(
          'Connection: ${connection is OctopusNotConnected
              ? 'Not connected'
              : app.userConnected
              ? 'Connected · ${app.effectiveUserId}'
              : 'Guest'}',
        ),
      );
      expect(copied, contains('onNavigateToProfileEdit (onModifyUser): Wired'));
    });
  }

  testWidgets('Developer tools opens Debug console over the current page', (
    tester,
  ) async {
    final app = AppState();
    addTearDown(app.dispose);
    await tester.pumpWidget(
      AppScope(
        state: app,
        child: const MaterialApp(home: DeveloperToolsScreen()),
      ),
    );
    await tester.tap(find.text('Debug console'));
    await tester.pumpAndSettle();
    expect(find.byType(DeveloperToolsScreen), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      tester.getSize(find.byType(BottomSheet)).height,
      lessThan(tester.view.physicalSize.height * 0.75),
    );
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(DeveloperToolsScreen), findsOneWidget);
  });

  const config = DemoConfig(
    apiKeySource: ApiKeySource.custom,
    customApiKey: 'unit-test-placeholder',
    userId: 'test-user',
    theme: AppThemeChoice.system,
    serverEnv: ServerEnv.demo,
    featureToggles: FeatureToggles(forceLogin: true, pushRegistration: false),
  );

  test('community names distinguish Demo from pasted and named keys', () {
    expect(config.communityLabel, 'Custom community');
    expect(
      config.copyWith(apiKeySource: ApiKeySource.demo).communityLabel,
      'Demo community',
    );
  });

  Future<void> pump(
    WidgetTester tester,
    Widget screen,
    AppState app, {
    double scale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AppScope(
        state: app,
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test(
    'unsupported selective URL preference restores and resets to SDK',
    () async {
      SharedPreferences.setMockInitialValues({
        'host_integration_v1': '{"url":"sampleRule"}',
      });
      final app = AppState();
      addTearDown(app.dispose);
      await app.restoreHostIntegration();
      expect(app.hostUrlHandling, HostUrlHandling.sdk);
      app.setHostUrlHandling(HostUrlHandling.sampleRule);
      expect(app.hostUrlHandling, HostUrlHandling.sdk);
      app.setHostUrlHandling(HostUrlHandling.inApp);
      await app.reset();
      expect(app.hostUrlHandling, HostUrlHandling.sdk);
    },
  );

  testWidgets('selective URL rule is shown as unavailable and disabled', (
    tester,
  ) async {
    final app = AppState();
    addTearDown(app.dispose);
    await pump(tester, const HostIntegrationScreen(), app);
    final option = find.widgetWithText(
      RadioListTile<HostUrlHandling>,
      'Sample rule (unavailable)',
    );
    await tester.scrollUntilVisible(
      option,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester.widget<RadioListTile<HostUrlHandling>>(option).enabled,
      isFalse,
    );
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(app.hostUrlHandling, HostUrlHandling.sdk);
  });

  testWidgets('host browser opens web links and delegates mailto to the OS', (
    tester,
  ) async {
    const launcher = MethodChannel('plugins.flutter.io/url_launcher');
    final launched = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(launcher, (call) async {
      launched.add(call);
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(launcher, null));
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const Scaffold();
          },
        ),
      ),
    );
    await tester.runAsync(() async {
      for (final url in ['https://example.org', 'mailto:sample@example.org']) {
        await openUrlOrCopy(
          context,
          url,
          clipLabel: 'test',
          mode: LaunchMode.inAppBrowserView,
        );
      }
    });
    expect(launched.map((call) => call.arguments['url']), [
      'https://example.org',
      'mailto:sample@example.org',
    ]);
    expect(launched.first.arguments['useWebView'], isTrue);
    expect(launched.last.arguments['useWebView'], isFalse);
    await tester.runAsync(
      () => openUrlOrCopy(
        context,
        'not a URL',
        clipLabel: 'test',
        mode: LaunchMode.inAppBrowserView,
      ),
    );
    await tester.pumpAndSettle();
    expect(launched, hasLength(2));
    expect(find.textContaining('copied to the clipboard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('debug kind filters combine with trimmed case-insensitive search', () {
    final entries = [
      DebugEntry(DebugEntryKind.event, 'PostCreated', 'hello'),
      DebugEntry(DebugEntryKind.state, 'connection', 'connected'),
      DebugEntry(DebugEntryKind.api, 'connectUser', 'user'),
    ];
    expect(
      filterDebugEntries(entries, ' CONNECT ', {
        DebugEntryKind.state,
        DebugEntryKind.api,
      }),
      hasLength(2),
    );
    expect(filterDebugEntries(entries, '', {}), isEmpty);
    expect(
      filterDebugEntries(entries, 'hello', {DebugEntryKind.event}).single.label,
      'PostCreated',
    );
  });

  test('debug recordings and exports mask credentials before storage', () {
    final log = RealDebugLog();
    addTearDown(log.dispose);
    log.apiCall('initialize', {
      'apiKey': 'unit-test-secret',
      'token': 'unit-test-token',
    });
    expect(log.entries.single.detail, isNot(contains('unit-test-secret')));
    expect(log.exportText(), isNot(contains('unit-test-token')));
    expect(log.exportJson(), contains('[redacted]'));
  });

  test(
    'appearance and preset force the SDK mode, persist, and restore system',
    () async {
      final app = AppState();
      addTearDown(app.dispose);
      await app.start(config);
      app.setThemeChoice(AppThemeChoice.dark);
      app.setThemePreset(false);
      expect(app.effectiveOctopusTheme()!.themeMode, OctopusThemeMode.dark);
      expect(app.activeThemeLabel, 'SDK default');
      app.setThemeChoice(AppThemeChoice.light);
      expect(app.effectiveOctopusTheme()!.themeMode, OctopusThemeMode.light);
      app.setThemeChoice(AppThemeChoice.system);
      expect(app.effectiveOctopusTheme()!.themeMode, isNull);
      await Future<void>.delayed(Duration.zero);
      final restored = await loadPersistedDemoConfig();
      expect(restored!.octopusNavyTheme, isFalse);
      expect(restored.theme, AppThemeChoice.system);
    },
  );

  test(
    'all ten language choices send the native override and survive restart',
    () async {
      final app = AppState();
      addTearDown(app.dispose);
      await app.start(config);
      calls.clear();
      expect(sdkLanguages.map((choice) => choice.$1), [
        '',
        'en',
        'fr',
        'de',
        'it',
        'pl',
        'pt',
        'es',
        'sv',
        'tr',
      ]);
      for (final (tag, _) in sdkLanguages) {
        await app.setLocaleTag(tag);
        expect(
          calls.last.arguments['languageCode'],
          tag.isEmpty ? isNull : tag,
        );
      }
      final restored = AppState();
      addTearDown(restored.dispose);
      await restored.restoreSdkLocale();
      expect(restored.localeTag, 'tr');
      await app.reset();
      expect(
        (await SharedPreferences.getInstance()).getString(
          sdkLocalePreferenceKey,
        ),
        isNull,
      );
    },
  );

  test(
    'bootstrap restores language locally and applies only after initialize',
    () async {
      SharedPreferences.setMockInitialValues({sdkLocalePreferenceKey: 'fr'});
      PackageInfo.setMockInitialValues(
        appName: 'Sample',
        packageName: 'test.sample',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
      var nativeInitialized = false;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockStreamHandler(
        const EventChannel('octopus_sdk_flutter/events'),
        MockStreamHandler.inline(onListen: (_, __) {}),
      );
      addTearDown(
        () => messenger.setMockStreamHandler(
          const EventChannel('octopus_sdk_flutter/events'),
          null,
        ),
      );
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'initialize') nativeInitialized = true;
        if (call.method == 'overrideDefaultLocale' && !nativeInitialized) {
          throw PlatformException(code: 'NOT_INITIALIZED');
        }
        return null;
      });
      final app = AppState();
      addTearDown(app.dispose);
      await app.bootstrap();
      expect(app.localeTag, 'fr');
      expect(
        calls.where((call) => call.method == 'overrideDefaultLocale'),
        isEmpty,
      );
      await app.start(config);
      expect(app.initError, isNull);
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
    },
  );

  test(
    'failed language override keeps the confirmed value and preference',
    () async {
      final app = AppState();
      addTearDown(app.dispose);
      await app.start(config);
      await app.setLocaleTag('fr');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => throw PlatformException(code: 'unavailable'),
          );
      await expectLater(
        app.setLocaleTag('de'),
        throwsA(isA<PlatformException>()),
      );
      expect(app.localeTag, 'fr');
      expect(
        (await SharedPreferences.getInstance()).getString(
          sdkLocalePreferenceKey,
        ),
        'fr',
      );
    },
  );

  test(
    'language requests share a native, state and persistence queue',
    () async {
      final app = AppState();
      addTearDown(app.dispose);
      await app.start(config);
      calls.clear();
      final firstNative = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.arguments['languageCode'] == 'fr') {
              await firstNative.future;
            }
            return null;
          });
      final first = app.setLocale(LocaleChoice.fr);
      await Future<void>.delayed(Duration.zero);
      final second = app.setLocaleTag('de');
      await Future<void>.delayed(Duration.zero);
      expect(calls, hasLength(1));
      firstNative.complete();
      await Future.wait([first, second]);
      expect(calls.map((call) => call.arguments['languageCode']), ['fr', 'de']);
      expect(app.localeTag, 'de');
      expect(
        (await SharedPreferences.getInstance()).getString(
          sdkLocalePreferenceKey,
        ),
        'de',
      );
    },
  );

  test('a failed language request does not block the next request', () async {
    final app = AppState();
    addTearDown(app.dispose);
    await app.start(config);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.arguments['languageCode'] == 'fr') {
            throw PlatformException(code: 'unavailable');
          }
          return null;
        });
    final failure = expectLater(
      app.setLocaleTag('fr'),
      throwsA(isA<PlatformException>()),
    );
    final next = app.setLocaleTag('de');
    await Future.wait([failure, next]);
    expect(app.localeTag, 'de');
    expect(
      (await SharedPreferences.getInstance()).getString(sdkLocalePreferenceKey),
      'de',
    );
  });

  testWidgets(
    'revisit sections start collapsed, preserve edits and feature toggles on Apply',
    (tester) async {
      final app = _RecordingApp();
      addTearDown(app.dispose);
      await pump(tester, const ConfigScreen(initialConfig: config), app);
      expect(find.text('Theme preset'), findsNothing);
      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();
      expect(app.applied!.theme, AppThemeChoice.dark);
      expect(app.applied!.serverEnv, ServerEnv.demo);
      expect(app.applied!.featureToggles.forceLogin, isTrue);
      expect(app.applied!.featureToggles.pushRegistration, isFalse);
      expect(app.applied!.customApiKey, config.customApiKey);
    },
  );

  test('custom endpoints preserve port through sample preferences', () {
    final draft = config.copyWith(
      serverEnv: ServerEnv.custom,
      customHost: 'example.org',
      customPort: 8443,
    );
    expect(draft.apiServer!.host, 'example.org');
    expect(draft.apiServer!.port, 8443);
    expect(draft.hostLabel, 'example.org:8443');
    expect(DemoConfig.fromJson(draft.toJson())!.customPort, 8443);
  });

  testWidgets(
    'invalid custom endpoint disables Apply and valid input commits',
    (tester) async {
      final app = _RecordingApp();
      addTearDown(app.dispose);
      await pump(
        tester,
        ConfigScreen(
          initialConfig: config.copyWith(
            serverEnv: ServerEnv.custom,
            customHost: 'example.org',
          ),
        ),
        app,
      );
      final section = find.widgetWithText(ExpansionTile, 'Server environment');
      await tester.ensureVisible(section);
      await tester.tap(section);
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.ensureVisible(fields.at(0));
      await tester.enterText(fields.at(0), 'https://example.org/path');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply'))
            .onPressed,
        isNull,
      );
      await tester.enterText(fields.at(0), 'example.org');
      await tester.enterText(fields.at(1), '65536');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply'))
            .onPressed,
        isNull,
      );
      await tester.enterText(fields.at(1), '8443');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();
      expect(app.applied!.apiServer!.port, 8443);
    },
  );

  testWidgets('expanded configuration controls reflow at 200%', (tester) async {
    final app = AppState();
    addTearDown(app.dispose);
    await pump(
      tester,
      const ConfigScreen(initialConfig: config),
      app,
      scale: 2,
    );
    for (final title in [
      'Theme',
      'Connect your users (SSO)',
      'Community',
      'Server environment',
    ]) {
      final target = find.widgetWithText(ExpansionTile, title);
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'console mounts, filters, clears and closes; drag dismisses a fresh sheet',
    (tester) async {
      final app = AppState();
      addTearDown(app.dispose);
      await pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDebugConsoleSheet(context),
              child: const Text('Open'),
            ),
          ),
        ),
        app,
      );
      debugLog.apiCall('connectUser');
      debugLog.note('connected');
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Debug Console'), findsOneWidget);
      expect(find.bySemanticsIdentifier('debug-filter-select'), findsOneWidget);
      await tester.enterText(find.byType(TextField), ' CONNECTUSER ');
      await tester.pump();
      expect(find.text('1 of 2 entries'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear Log'));
      await tester.pump();
      expect(find.text('0 of 0 entries'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Debug Console'), findsNothing);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.fling(find.byType(BottomSheet), const Offset(0, 700), 1600);
      await tester.pumpAndSettle();
      expect(find.text('Debug Console'), findsNothing);
    },
  );

  for (final feedbackEnabled in [false, true]) {
    testWidgets('support rows have dividers with feedback=$feedbackEnabled', (
      tester,
    ) async {
      final previousOpener = sampleFeedbackOpener;
      addTearDown(() => sampleFeedbackOpener = previousOpener);
      sampleFeedbackOpener = feedbackEnabled ? (_, _) async {} : null;
      final app = AppState();
      addTearDown(app.dispose);
      await pump(tester, const Scaffold(body: SettingsTab()), app);
      final list = tester.widget<ListView>(find.byType(ListView));
      final children =
          (list.childrenDelegate as SliverChildListDelegate).children;
      final supportRows = [
        'settings-devtools-entry',
        if (feedbackEnabled) 'settings-feedback-entry',
        'settings-about-entry',
      ];
      for (var i = 1; i < supportRows.length; i++) {
        final before = children.indexWhere(
          (child) =>
              child is SampleNavTile && child.identifier == supportRows[i - 1],
        );
        final after = children.indexWhere(
          (child) =>
              child is SampleNavTile && child.identifier == supportRows[i],
        );
        expect(before, greaterThanOrEqualTo(0));
        expect(after, greaterThan(before));
        expect(children.sublist(before + 1, after), hasLength(1));
        expect(children[before + 1], isA<SampleListDivider>());
      }
      expect(
        children.whereType<SampleNavTile>().any(
          (tile) => tile.identifier == 'settings-feedback-entry',
        ),
        feedbackEnabled,
      );
    });
  }

  for (final brightness in Brightness.values) {
    for (final screen in <Widget>[
      const Scaffold(body: SettingsTab()),
      const AppearanceScreen(),
      const LanguageScreen(),
      const DeveloperToolsScreen(),
      const HostIntegrationScreen(),
      const AboutScreen(),
      const ConfigScreen(initialConfig: config),
    ]) {
      testWidgets(
        '${screen.runtimeType} reflows at 200% in ${brightness.name}',
        (tester) async {
          final app = AppState();
          addTearDown(app.dispose);
          await app.start(config);
          await pump(tester, screen, app, scale: 2, brightness: brightness);
          expect(tester.takeException(), isNull);
          for (var i = 0; i < 5; i++) {
            final scroll = find.byType(Scrollable).first;
            await tester.drag(scroll, const Offset(0, -600));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          if (screen is AboutScreen) {
            expect(find.text('Design reference'), findsNothing);
          }
        },
      );
    }
  }
}
