import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/main.dart';
import 'package:octopus_sdk_flutter_example/sample_tab.dart';
import 'package:octopus_sdk_flutter_example/scenarios/community_data_scenario.dart';
import 'package:octopus_sdk_flutter_example/scenarios/live_community_config_card.dart';
import 'package:octopus_sdk_flutter_example/scenarios/scenarios_screen.dart';
import 'package:octopus_sdk_flutter_example/widgets/scenario_scaffold.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sample_shell_test.dart' show pumpShell, selectTab;

const _off = OctopusDebugCommunityConfig(
  exposeClientUserId: false,
  forceLoginOnStrongActions: false,
  displayAccountAge: false,
);
const _on = OctopusDebugCommunityConfig(
  exposeClientUserId: true,
  forceLoginOnStrongActions: true,
  displayAccountAge: true,
);

class _Sdk extends OctopusSDK {
  int reads = 0;
  Future<OctopusDebugCommunityConfig>? nextRead;
  final lookups = <(String?, String?)>[];
  @override
  Future<OctopusDebugCommunityConfig> debugGetCommunityConfig() {
    reads++;
    return nextRead ?? Future.value(_off);
  }

  @override
  Future<OctopusCommunityData?> fetchCommunityData({
    String? profileId,
    String? clientUserId,
  }) async {
    lookups.add((profileId, clientUserId));
    return null;
  }
}

class _App extends AppState {
  final sdk = _Sdk();
  bool ready = true;
  int session = 0;
  @override
  OctopusSDK get octopus => sdk;
  @override
  bool get initialized => ready;
  @override
  int get communitySession => session;

  void changeSession() {
    session++;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    messenger.setMockStreamHandler(
      const EventChannel('octopus_sdk_flutter/events'),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('octopus_sdk_flutter'),
      (_) async => null,
    );
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(
      const MethodChannel('octopus_sdk_flutter'),
      null,
    );
  });

  test('first launch preserves the build host, including the SDK default', () {
    for (final host in [
      '',
      'api.8pus.io',
      'feature.example.test',
      '  demo.example.test  ',
    ]) {
      final config = buildInitialDemoConfig(host: host, userId: 'sample-user');
      expect(config.resolvedHost, host.trim());
      expect(
        config.serverEnv,
        host.trim().isEmpty
            ? ServerEnv.prod
            : host.trim() == 'api.8pus.io'
            ? ServerEnv.custom
            : ServerEnv.demo,
      );
      expect(config.userId, 'sample-user');
    }
  });

  test(
    'live config masks even short keys and keeps unknown separate from off',
    () {
      expect(maskScenarioApiKey(null), '—');
      expect(maskScenarioApiKey(' '), '—');
      expect(maskScenarioApiKey('x'), '••••');
      expect(maskScenarioApiKey('fixture-only'), '••••');
      expect(
        liveCommunityConfigRows(null, null).skip(1).map((r) => r.$2),
        everyElement('—'),
      );
      expect(liveCommunityConfigRows(_off, null)[1].$2, '✗ off');
      expect(liveCommunityConfigRows(_on, null)[1].$2, '✓ on');
    },
  );

  test(
    'lifecycle reset/stop retain config and restart uses the saved host',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(
        const MethodChannel('octopus_sdk_flutter'),
        (call) async {
          calls.add(call);
          return null;
        },
      );
      final app = AppState();
      addTearDown(app.dispose);
      const config = DemoConfig(
        apiKeySource: ApiKeySource.custom,
        customApiKey: 'fixture-only',
        userId: 'sample-user',
        theme: AppThemeChoice.system,
        serverEnv: ServerEnv.custom,
        customHost: 'demo.example.test',
      );
      await app.start(config);
      expect(app.initialized, isTrue);
      await app.resetSessionForScenario();
      expect(calls.any((c) => c.method == 'reset'), isTrue);
      expect(app.initialized, isTrue);
      expect(app.config, same(config));
      await app.stopForScenario();
      expect(calls.last.method, 'stop');
      expect(app.initialized, isFalse);
      expect(app.connectionState, isNull);
      expect(app.config, same(config));
      await app.restartForScenario();
      final initialize = calls.lastWhere((c) => c.method == 'initialize');
      expect(
        ((initialize.arguments as Map)['apiServer'] as Map)['host'],
        'demo.example.test',
      );
      expect(app.initialized, isTrue);
      await app.stopForScenario();
    },
  );

  test(
    'switch then stop/restart retains the live community and host',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(
        const MethodChannel('octopus_sdk_flutter'),
        (call) async {
          calls.add(call);
          return null;
        },
      );
      final app = AppState();
      addTearDown(app.dispose);
      const config = DemoConfig(
        apiKeySource: ApiKeySource.custom,
        customApiKey: 'fixture-community-a',
        userId: 'sample-user',
        theme: AppThemeChoice.dark,
        serverEnv: ServerEnv.custom,
        customHost: 'demo.example.test',
      );
      await app.start(config);
      await app.switchToCommunity('fixture-community-b');
      await app.stopForScenario();
      await app.restartForScenario();
      final initialize = calls.lastWhere((call) => call.method == 'initialize');
      final arguments = initialize.arguments as Map;
      expect(arguments['apiKey'], 'fixture-community-b');
      expect((arguments['apiServer'] as Map)['host'], 'demo.example.test');
      expect(app.activeApiKey, 'fixture-community-b');
      expect(app.config!.theme, AppThemeChoice.dark);
      expect(app.config!.userId, 'sample-user');
      expect(
        app.config!.toJson().values,
        isNot(contains('fixture-community-b')),
      );
      await app.stopForScenario();
    },
  );

  testWidgets('real cold shell opens Scenarios without a configuration gate', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'Sample',
      packageName: 'sample',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await tester.pumpWidget(const OctopusDemoApp());
    await tester.pumpAndSettle();
    expect(find.byType(ScenariosTab), findsOneWidget);
    expect(find.text('Configure the SDK, then start it.'), findsNothing);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Configuration'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Configuration'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'search comes before launch/config, profile finds three cards and empty echoes the query',
    (tester) async {
      await pumpShell(tester);
      expect(
        tester.getTopLeft(find.byType(TextField)).dy,
        lessThan(tester.getTopLeft(find.text('Open the community')).dy),
      );
      expect(find.text('Live community config'), findsOneWidget);
      for (final label in ['Tab', 'Modal', 'Sheet', 'Full screen']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.enterText(find.byType(TextField), 'profile');
      await tester.pumpAndSettle();
      expect(find.text('Open the community'), findsNothing);
      expect(find.text('Live community config'), findsNothing);
      for (final id in [
        'unifiedProfile',
        'communityData',
        'profileFieldsLock',
      ]) {
        expect(
          find.bySemanticsIdentifier('scenarios-$id-card'),
          findsOneWidget,
        );
      }
      expect(find.text('Read a member\'s community profile'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump();
      expect(find.text('No scenario matches "zzzz".'), findsOneWidget);
    },
  );

  testWidgets(
    'title collapses with list scroll and search stays above the list',
    (tester) async {
      await pumpShell(tester);
      final title = find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Scenarios'),
      );
      expect(tester.widget<Text>(title).style!.fontSize, 28);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -350),
      );
      await tester.pumpAndSettle();
      expect(
        DefaultTextStyle.of(
          tester.element(title),
        ).style.merge(tester.widget<Text>(title).style).fontSize,
        22,
      );
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
    },
  );

  testWidgets(
    'groups start collapsed and collapse again after leaving the tab',
    (tester) async {
      await pumpShell(tester);
      expect(
        find.bySemanticsIdentifier('scenarios-connection-card'),
        findsNothing,
      );
      await tester.ensureVisible(
        find.bySemanticsIdentifier('scenarios-section-sso'),
      );
      await tester.tap(find.bySemanticsIdentifier('scenarios-section-sso'));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsIdentifier('scenarios-connection-card'),
        findsOneWidget,
      );
      await selectTab(tester, SampleTab.settings);
      await selectTab(tester, SampleTab.scenarios);
      expect(
        find.bySemanticsIdentifier('scenarios-connection-card'),
        findsNothing,
      );
    },
  );

  testWidgets('catalog order and counts match the six reference groups', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 20000);
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
    final cases = <String, List<String>>{
      'sso': [
        'unifiedProfile',
        'connection',
        'communityData',
        'profileFieldsLock',
        'forceNicknameChoice',
        'termsAcceptance',
        'consentTexts',
        'refreshEntitlements',
      ],
      'presentation': ['initialScreen', 'fullscreen', 'modal', 'sheet'],
      'community': [
        'groups',
        'syncFollowGroups',
        'communityAccess',
        'bridge',
        'createPost',
        'reactions',
        'contentOptions',
        'groupAccessDenied',
      ],
      'notifications': ['notSeenNotifications', 'pushNotifications'],
      'themeLanguage': ['locale', 'theme'],
      'hostCallbacks': [
        'hostLifecycles',
        'customEvents',
        'lifecycle',
        'events',
        'trackABTests',
        'forceOctopusABTests',
      ],
    };
    double previous = 0;
    for (final entry in cases.entries) {
      final header = find.bySemanticsIdentifier(
        'scenarios-section-${entry.key}',
      );
      expect(tester.getTopLeft(header).dy, greaterThan(previous));
      expect(
        find.descendant(
          of: header,
          matching: find.text('${entry.value.length}'),
        ),
        findsOneWidget,
      );
      await tester.tap(header);
      await tester.pump();
      for (final id in entry.value) {
        final card = find.bySemanticsIdentifier('scenarios-$id-card');
        expect(card, findsOneWidget);
        expect(tester.getTopLeft(card).dy, greaterThan(previous));
        previous = tester.getTopLeft(card).dy;
      }
    }
  });

  testWidgets(
    'member lookup executes the typed ID and selected identifier kind',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = _App();
      addTearDown(app.dispose);
      await tester.pumpWidget(
        AppScope(
          state: app,
          child: const MaterialApp(home: CommunityDataScenario()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Not run yet'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'User ID'),
        '  member-from-input  ',
      );
      await tester.tap(find.bySemanticsIdentifier('communityData-execute'));
      await tester.pumpAndSettle();
      expect(app.sdk.lookups.last, (null, 'member-from-input'));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      await tester.tap(find.bySemanticsIdentifier('communityData-execute'));
      await tester.pumpAndSettle();
      expect(app.sdk.lookups.last, ('member-from-input', null));
      await tester.enterText(find.widgetWithText(TextField, 'User ID'), ' ');
      await tester.tap(find.bySemanticsIdentifier('communityData-execute'));
      await tester.pumpAndSettle();
      expect(app.sdk.lookups, hasLength(2));
      expect(find.text('Enter a User ID.'), findsOneWidget);
    },
  );

  testWidgets(
    'live config ignores stale responses and stops polling when hidden or disposed',
    (tester) async {
      final app = _App();
      addTearDown(app.dispose);
      final old = Completer<OctopusDebugCommunityConfig>();
      app.sdk.nextRead = old.future;
      Widget page(bool active) => AppScope(
        state: app,
        child: MaterialApp(
          home: Scaffold(body: LiveCommunityConfigCard(active: active)),
        ),
      );
      await tester.pumpWidget(page(true));
      await tester.pump(const Duration(seconds: 2));
      expect(app.sdk.reads, 1);
      final current = Completer<OctopusDebugCommunityConfig>();
      app.sdk.nextRead = current.future;
      app.changeSession();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(app.sdk.reads, 2);
      current.complete(_off);
      await tester.pump();
      old.complete(_on);
      await tester.pump();
      expect(find.text('✓ on'), findsNothing);
      expect(find.text('✗ off'), findsNWidgets(4));
      await tester.pumpWidget(page(false));
      await tester.pump(const Duration(seconds: 5));
      expect(app.sdk.reads, 2);
      await tester.pumpWidget(page(true));
      await tester.pump(const Duration(milliseconds: 10));
      expect(app.sdk.reads, greaterThan(2));
      final readsBeforeDispose = app.sdk.reads;
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      expect(app.sdk.reads, readsBeforeDispose);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Scenarios and Unified Profile fit portrait at font scale $scale',
      (tester) async {
        await pumpShell(tester, scale: scale);
        expect(tester.takeException(), isNull);
        await tester.enterText(find.byType(TextField), 'Unified Profile');
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.bySemanticsIdentifier('scenarios-unifiedProfile-card'),
        );
        await tester.tap(
          find.bySemanticsIdentifier('scenarios-unifiedProfile-card'),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BackButton), findsOneWidget);
        expect(find.byType(ScenarioScaffold), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
