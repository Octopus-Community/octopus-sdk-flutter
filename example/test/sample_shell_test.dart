import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/branding.dart';
import 'package:octopus_sdk_flutter_example/community/community_screen.dart';
import 'package:octopus_sdk_flutter_example/config/config_screen.dart';
import 'package:octopus_sdk_flutter_example/design.dart';
import 'package:octopus_sdk_flutter_example/feature_toggles.dart';
import 'package:octopus_sdk_flutter_example/main.dart';
import 'package:octopus_sdk_flutter_example/sample_tab.dart';
import 'package:octopus_sdk_flutter_example/scenarios/scenarios_screen.dart';
import 'package:octopus_sdk_flutter_example/settings/about_screen.dart';
import 'package:octopus_sdk_flutter_example/settings/account_screen.dart';
import 'package:octopus_sdk_flutter_example/settings/sdk_summary.dart';
import 'package:octopus_sdk_flutter_example/settings/settings_screen.dart';
import 'package:octopus_sdk_flutter_example/widgets/scenario_scaffold.dart';

Future<AppState> pumpShell(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.android,
  double scale = 1,
  Brightness brightness = Brightness.light,
  Widget? home,
  AppState? state,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 34);
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  final app = state ?? AppState();
  addTearDown(app.dispose);
  await tester.pumpWidget(
    AppScope(
      state: app,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light).copyWith(platform: platform),
        darkTheme: buildAppTheme(Brightness.dark).copyWith(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: octopusDemoAppBuilderWith(context, child, showWarning: false),
        ),
        home: home ?? MainScreen(app: app),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return app;
}

Future<void> selectTab(WidgetTester tester, SampleTab tab) async {
  final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
  bar.onDestinationSelected!(tab.index);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _scalePreset(ScenarioResultSink result) async => result('OK');

class _FailedAppState extends AppState {
  @override
  String? get initError => 'Initialization failed';
}

class _ReadyAppState extends AppState {
  @override
  bool get initialized => true;
}

void main() {
  testWidgets(
    'three tabs, starts on Scenarios, named requests use the same order',
    (tester) async {
      final app = await pumpShell(tester);
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(
        bar.destinations.cast<NavigationDestination>().map((d) => d.label),
        ['Scenarios', 'Community', 'Settings'],
      );
      expect(bar.selectedIndex, SampleTab.scenarios.index);
      expect(find.byType(ScenariosTab), findsOneWidget);
      app.requestCommunityTab(null);
      await tester.pump();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        SampleTab.community.index,
      );
      app.requestTab(SampleTab.settings.index);
      await tester.pump();
      expect(find.byType(SettingsTab), findsOneWidget);
    },
  );

  testWidgets('Community is built on first visit and retained when hidden', (
    tester,
  ) async {
    await pumpShell(tester);
    expect(find.byType(CommunityTab, skipOffstage: false), findsNothing);
    await selectTab(tester, SampleTab.settings);
    expect(find.byType(CommunityTab, skipOffstage: false), findsNothing);
    await selectTab(tester, SampleTab.community);
    final community = tester.element(find.byType(CommunityTab));
    await selectTab(tester, SampleTab.scenarios);
    expect(find.byType(CommunityTab), findsNothing);
    expect(
      tester.element(find.byType(CommunityTab, skipOffstage: false)),
      same(community),
    );
    await selectTab(tester, SampleTab.community);
    expect(tester.element(find.byType(CommunityTab)), same(community));
  });

  testWidgets('system Back returns to Scenarios before exiting the shell', (
    tester,
  ) async {
    final platformCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpShell(tester);
    for (final tab in [SampleTab.community, SampleTab.settings]) {
      await selectTab(tester, tab);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        SampleTab.scenarios.index,
      );
      expect(platformCalls, isNot(contains('SystemNavigator.pop')));
    }
    expect(await tester.binding.handlePopRoute(), isFalse);
    await tester.pumpAndSettle();
    expect(
      platformCalls.where((call) => call == 'SystemNavigator.pop'),
      hasLength(1),
    );
  });

  testWidgets('system Back pops pushed pages before changing tabs', (
    tester,
  ) async {
    // A terminal SDK state avoids an indeterminate Community startup spinner.
    await pumpShell(tester, state: _FailedAppState());
    for (final (tab, page) in <(SampleTab, Widget)>[
      (SampleTab.settings, const AboutScreen()),
      (SampleTab.settings, const ConfigScreen()),
      (SampleTab.community, const ConfigScreen()),
      (
        SampleTab.scenarios,
        const ScenarioScaffold(
          title: 'Detail',
          description: 'A scenario',
          presets: [],
          resultTestId: 'back-scenario-result',
        ),
      ),
    ]) {
      await selectTab(tester, tab);
      final shell = tester.element(find.byType(MainScreen));
      Navigator.of(shell).push(MaterialPageRoute<void>(builder: (_) => page));
      await tester.pumpAndSettle();
      expect(find.byWidget(page), findsOneWidget);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byWidget(page), findsNothing);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        tab.index,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('all tab elements, search and scroll survive switches', (
    tester,
  ) async {
    await pumpShell(tester);
    await selectTab(tester, SampleTab.community);
    await selectTab(tester, SampleTab.scenarios);
    final elements = [
      tester.element(find.byType(ScenariosTab, skipOffstage: false)),
      tester.element(find.byType(CommunityTab, skipOffstage: false)),
      tester.element(find.byType(SettingsTab, skipOffstage: false)),
    ];
    await tester.enterText(find.byType(TextField), 'connection');
    await tester.pump();
    final search = tester.element(find.byType(TextField));
    final scenariosScroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(ScenariosTab),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    scenariosScroll.position.jumpTo(scenariosScroll.position.maxScrollExtent);
    final scenariosOffset = scenariosScroll.position.pixels;
    await selectTab(tester, SampleTab.settings);
    final settingsScroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(SettingsTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    settingsScroll.position.jumpTo(180);
    await selectTab(tester, SampleTab.community);
    await selectTab(tester, SampleTab.scenarios);
    expect(tester.element(find.byType(TextField)), same(search));
    expect(find.text('connection'), findsOneWidget);
    expect(scenariosScroll.position.pixels, scenariosOffset);
    for (var i = 0; i < elements.length; i++) {
      final type = [ScenariosTab, CommunityTab, SettingsTab][i];
      expect(
        tester.element(find.byType(type, skipOffstage: false)),
        same(elements[i]),
      );
    }
    await selectTab(tester, SampleTab.settings);
    expect(settingsScroll.position.pixels, 180);
  });

  testWidgets('community shortcuts use Android labels and hide during search', (
    tester,
  ) async {
    await pumpShell(tester);
    final card = find.bySemanticsIdentifier('scenarios-open-community-card');
    expect(card, findsOneWidget);
    expect(find.text('Open the community'), findsOneWidget);
    for (final (id, label) in [
      ('open-community-tab-button', 'Tab'),
      ('open-community-modal-button', 'Modal'),
      ('open-community-sheet-button', 'Sheet'),
    ]) {
      expect(
        find.descendant(
          of: find.bySemanticsIdentifier(id),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
    await tester.enterText(find.byType(TextField), 'connection');
    await tester.pump();
    expect(card, findsNothing);
    expect(
      find.bySemanticsIdentifier('open-community-tab-button'),
      findsNothing,
    );
    expect(find.text('No scenario matches your search.'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(card, findsOneWidget);
  });

  testWidgets(
    'section anchor from Settings returns to Scenarios once; pushed back retains the tab',
    (tester) async {
      final app = await pumpShell(tester);
      await selectTab(tester, SampleTab.settings);
      app.requestScenariosSection('notifications');
      await tester.pumpAndSettle();
      final header = find.bySemanticsIdentifier(
        'scenarios-section-notifications',
      );
      expect(header.hitTestable(), findsOneWidget);
      expect(app.takeRequestedScenariosSection(), isNull);
      final element = tester.element(find.byType(ScenariosTab));
      Navigator.of(element).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Detail')),
            body: const Text('Detail'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(ScenariosTab)), same(element));
      expect(header.hitTestable(), findsOneWidget);
    },
  );

  testWidgets('former Home functions have reachable destinations', (
    tester,
  ) async {
    await pumpShell(tester);
    expect(
      find.bySemanticsIdentifier('open-community-tab-button'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('open-community-sheet-button'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('open-community-modal-button'),
      findsOneWidget,
    );
    await tester.tap(find.bySemanticsIdentifier('open-community-tab-button'));
    await tester.pump();
    expect(find.byType(CommunityTab), findsOneWidget);
    await selectTab(tester, SampleTab.settings);
    expect(find.byType(CommunitySettingsSummary), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('About'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(SettingsTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
    await tester.tap(find.bySemanticsIdentifier('settings-about-entry'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(find.bySemanticsIdentifier('about-versions'), findsOneWidget);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in Brightness.values) {
      testWidgets('$platform $brightness SDK Running stays visible at 200%', (
        tester,
      ) async {
        final app = _ReadyAppState();
        await pumpShell(
          tester,
          platform: platform,
          brightness: brightness,
          scale: 2,
          state: app,
        );
        await selectTab(tester, SampleTab.settings);
        final status = find.byType(CommunitySettingsSummary);
        expect(
          find
              .descendant(
                of: status,
                matching: find.text('Started, no session'),
              )
              .hitTestable(),
          findsOneWidget,
        );
        expect(
          find.descendant(of: status, matching: find.byType(SampleDot)),
          findsOneWidget,
        );
        expect(
          tester.getSize(find.text('Started, no session')).height,
          greaterThanOrEqualTo(40),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('$platform $brightness pushed controls at 200%', (
        tester,
      ) async {
        for (final page in <Widget>[
          const ConfigScreen(),
          const AccountScreen(),
          const AboutScreen(),
          const ScenarioSectionScope(
            sectionId: 'notifications',
            featureToggle: FeatureToggle.pushRegistration,
            child: ScenarioScaffold(
              title: 'Scenario',
              description: 'Sample description',
              presets: [
                ScenarioPreset(
                  testId: 'scale-run-preset',
                  label: 'Preset 1 · Check',
                  onRun: _scalePreset,
                ),
              ],
              resultTestId: 'scale-result',
            ),
          ),
        ]) {
          await pumpShell(
            tester,
            platform: platform,
            brightness: brightness,
            scale: 2,
            home: page,
          );
          expect(tester.takeException(), isNull, reason: '${page.runtimeType}');
          if (page is ScenarioSectionScope) {
            expect(
              tester.getSize(find.text('Execute')).height,
              greaterThanOrEqualTo(40),
            );
          }
        }
      });
      testWidgets('$platform $brightness Community error controls at 200%', (
        tester,
      ) async {
        await pumpShell(
          tester,
          platform: platform,
          brightness: brightness,
          scale: 2,
          state: _FailedAppState(),
          home: const Scaffold(body: SafeArea(child: CommunityTab())),
        );
        expect(tester.takeException(), isNull);
        for (final label in ['Retry', 'Config']) {
          expect(find.text(label).hitTestable(), findsOneWidget);
          expect(
            tester
                .getSize(
                  find.ancestor(
                    of: find.text(label),
                    matching: find.byType(TextButton),
                  ),
                )
                .height,
            greaterThanOrEqualTo(48),
          );
        }
      });
      testWidgets(
        '$platform $brightness at 200% respects safe areas and fits controls',
        (tester) async {
          await pumpShell(
            tester,
            platform: platform,
            scale: 2,
            brightness: brightness,
          );
          expect(
            Theme.of(tester.element(find.byType(MainScreen))).brightness,
            brightness,
          );
          for (final tab in SampleTab.values) {
            await selectTab(tester, tab);
            expect(tester.takeException(), isNull);
            final barRect = tester.getRect(find.byType(NavigationBar));
            expect(barRect.height, greaterThanOrEqualTo(48));
            expect(barRect.bottom, lessThanOrEqualTo(844));
          }
          await selectTab(tester, SampleTab.scenarios);
          final open = find.bySemanticsIdentifier('open-community-tab-button');
          await tester.ensureVisible(open);
          await tester.pumpAndSettle();
          final rect = tester.getRect(open);
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(rect.top, greaterThanOrEqualTo(24));
          expect(
            rect.bottom,
            lessThan(tester.getRect(find.byType(NavigationBar)).top),
          );
          for (final label in ['Sheet', 'Modal']) {
            expect(
              tester
                  .getSize(
                    find.ancestor(
                      of: find.text(label),
                      matching: find.byType(OutlinedButton),
                    ),
                  )
                  .height,
              greaterThanOrEqualTo(48),
            );
          }
          await selectTab(tester, SampleTab.settings);
          await tester.scrollUntilVisible(
            find.text('Reset Configuration'),
            200,
            scrollable: find
                .descendant(
                  of: find.byType(SettingsTab),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
