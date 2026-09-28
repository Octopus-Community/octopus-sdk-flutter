import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/config/config_screen.dart';
import 'package:octopus_sdk_flutter_example/feature_toggles.dart';
import 'package:octopus_sdk_flutter_example/scenarios/scenarios_screen.dart';
import 'package:octopus_sdk_flutter_example/widgets/scenario_scaffold.dart';

/// In-app links name a section, and must land on it: Config scrolled to the
/// anchored section, the Scenarios tab on the section a scenario came from.
void main() {
  // A phone-sized surface, so the lower sections start below the fold and a
  // landing is something the scroll offset has to do.
  const viewport = Size(400, 800);

  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  bool onScreen(WidgetTester tester, Finder finder) {
    final rect = tester.getRect(finder);
    return rect.top >= 0 && rect.top < viewport.height;
  }

  group('ConfigSection.fromAnchor', () {
    test('maps each link anchor to its section', () {
      expect(ConfigSection.fromAnchor('community'), ConfigSection.community);
      expect(ConfigSection.fromAnchor('server'), ConfigSection.server);
      expect(ConfigSection.fromAnchor('auth'), ConfigSection.auth);
      expect(
        ConfigSection.fromAnchor('integration'),
        ConfigSection.integration,
      );
      expect(ConfigSection.fromAnchor('theme'), ConfigSection.theme);
    });

    test('an unknown or absent anchor lands nowhere', () {
      expect(ConfigSection.fromAnchor('nope'), isNull);
      expect(ConfigSection.fromAnchor(''), isNull);
      expect(ConfigSection.fromAnchor(null), isNull);
    });

    test('each anchor targets the section the screen renders', () {
      // The identifiers the QA tooling already reads, unchanged.
      expect(ConfigSection.community.identifier, 'config-section-community');
      expect(ConfigSection.server.identifier, 'config-section-server');
      expect(ConfigSection.auth.identifier, 'config-section-auth');
      expect(ConfigSection.theme.identifier, 'config-section-theme');
      expect(
        ConfigSection.integration.identifier,
        'config-section-hostCallbacks',
      );
      expect(ConfigSection.integration.title, 'Host callbacks');
    });
  });

  group('ConfigScreen anchor', () {
    testWidgets('without an anchor the form opens at the top', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(const MaterialApp(home: ConfigScreen()));
      await tester.pumpAndSettle();

      final target = find.bySemanticsIdentifier(
        ConfigSection.integration.identifier,
      );
      expect(target, findsOneWidget);
      expect(onScreen(tester, target), isFalse);
    });

    testWidgets('lands on the anchored section, once', (tester) async {
      usePhoneSurface(tester);
      Widget screen() => const MaterialApp(
        home: ConfigScreen(
          entry: ConfigEntry.revisit,
          anchor: ConfigSection.integration,
        ),
      );
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();

      final target = find.bySemanticsIdentifier(
        ConfigSection.integration.identifier,
      );
      expect(onScreen(tester, target), isTrue);

      // Scroll away, then rebuild: the anchor is spent, the tester's own
      // scroll position stays.
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 5000),
      );
      await tester.pumpAndSettle();
      expect(onScreen(tester, target), isFalse);
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(onScreen(tester, target), isFalse);
    });

    testWidgets('openConfigScreen from a link lands on its section', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        AppScope(
          state: AppState(),
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () =>
                        openConfigScreen(context, anchor: ConfigSection.auth),
                    child: const Text('link'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('link'));
      await tester.pumpAndSettle();

      expect(find.text('Change Configuration'), findsOneWidget);
      expect(
        onScreen(
          tester,
          find.bySemanticsIdentifier(ConfigSection.auth.identifier),
        ),
        isTrue,
      );
    });
  });

  group('Scenarios section request', () {
    test('is taken once', () {
      final app = AppState();
      app.requestScenariosSection('notifications');
      expect(app.takeRequestedScenariosSection(), 'notifications');
      expect(app.takeRequestedScenariosSection(), isNull);
    });

    testWidgets('"Change it in Scenarios" asks for the scenario\'s section', (
      tester,
    ) async {
      final app = AppState();
      await tester.pumpWidget(
        AppScope(
          state: app,
          child: const MaterialApp(
            home: ScenarioSectionScope(
              sectionId: 'notifications',
              featureToggle: FeatureToggle.pushRegistration,
              child: ScenarioScaffold(
                title: 'Scenario',
                description: 'A scenario under a feature toggle.',
                presets: [],
                resultTestId: 'scenario-result',
              ),
            ),
          ),
        ),
      );
      final row = find.bySemanticsIdentifier('scenario-feature-state');
      expect(row, findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(app.takeRequestedScenariosSection(), 'notifications');
    });

    // Runs before the landing test below: the expanded state is app-wide, and
    // the landing expands its section.
    testWidgets('without a request no section is opened', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        AppScope(
          state: AppState(),
          child: const MaterialApp(home: Scaffold(body: ScenariosTab())),
        ),
      );
      await tester.pumpAndSettle();

      // Collapsed, the six headers fit a phone: the section's cards are what
      // a landing has to bring on screen.
      expect(find.bySemanticsIdentifier('scenarios-events-card'), findsNothing);
    });

    testWidgets('the Scenarios tab opens on the requested section', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final app = AppState()..requestScenariosSection('hostCallbacks');
      await tester.pumpWidget(
        AppScope(
          state: app,
          child: const MaterialApp(home: Scaffold(body: ScenariosTab())),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        onScreen(
          tester,
          find.bySemanticsIdentifier('scenarios-section-hostCallbacks'),
        ),
        isTrue,
      );
      // Opened and scrolled to: its first card is on screen.
      expect(
        onScreen(tester, find.bySemanticsIdentifier('scenarios-events-card')),
        isTrue,
      );
      // Spent: nothing left for a later rebuild to replay.
      expect(app.takeRequestedScenariosSection(), isNull);
    });
  });
}
