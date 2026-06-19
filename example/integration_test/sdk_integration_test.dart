import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:octopus_sdk_flutter_example/main.dart' as app;

/// End-to-end smoke tests for the canonical sample shell.
///
/// These run on a real device / emulator (`flutter test integration_test`) and
/// are designed to be **CI-resilient without secrets**: the sample launches +
/// navigates even when no `--dart-define=OCTOPUS_API_KEY` is injected (the SDK
/// just records an init error on the Home dashboard — see
/// `octopus_demo_config.dart`). So every assertion below is about the host
/// **shell structure + navigation**, never about backend results (which are
/// non-deterministic in CI).
///
/// Element lookups use the verbatim catalog test ids (Semantics identifiers)
/// so they mirror the QA contract.
///
/// Two deliberate avoidances keep the suite non-flaky:
///  1. We never `pumpAndSettle` on the **Community** tab — it hosts a native
///     PlatformView whose continuous compositing never reaches a settled frame,
///     which would hang `pumpAndSettle`. The shell-level tests stay on the
///     pure-Flutter tabs (Home / Scenarios / Settings / Debug).
///  2. Scenario presets are exercised for "does not throw / renders a result"
///     only — we assert the result panel appears, not its backend-dependent
///     text.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Boots the app and taps through the Config screen so the bottom-nav shell
  /// is mounted. Leaves the harness on the Home tab.
  ///
  /// Auto-restore note: PR #91 made the sample persist its DemoConfig to
  /// `shared_preferences` and reload it on launch, so a 2nd `app.main()` in
  /// the same integration_test session lands directly on the shell — the
  /// Config screen never re-appears. Tap-through only when it's actually
  /// there, otherwise the harness is already on the bottom-nav shell.
  Future<void> startToShell(WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final config = find.bySemanticsIdentifier('config-screen');
    if (config.evaluate().isNotEmpty) {
      // PR #114 added the User ID picker between the API-key picker and
      // the theme selector, pushing the Start button below the viewport on
      // CI device sizes. `find.bySemanticsIdentifier` doesn't see widgets
      // whose render objects haven't been laid out yet, so scroll the
      // Config ListView until the Start button is on-screen before tapping.
      final start = find.bySemanticsIdentifier('config-start-button');
      // Scope to the Config screen's Scrollable rather than
      // `find.byType(Scrollable).first` — the latter walks the WHOLE
      // element tree (including any future hidden routes / horizontal
      // chip rows). `ListView` itself is also a `Scrollable`, so the
      // descendant scope still matches multiple widgets — `.first` over
      // a scoped subtree is well-defined (parent-before-descendant in
      // element traversal order) and `scrollUntilVisible` needs a
      // single Scrollable.
      await tester.scrollUntilVisible(
        start,
        200,
        scrollable: find
            .descendant(of: config, matching: find.byType(Scrollable))
            .first,
      );
      expect(start, findsOneWidget);
      await tester.tap(start);
      // start() sets the DemoConfig and the root rebuilds to the shell
      // regardless of init success, so the shell appears even keyless.
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }
  }

  group('Sample shell', () {
    testWidgets('Config → Start reveals all five bottom-nav tabs', (
      tester,
    ) async {
      await startToShell(tester);

      // The five-tab shell (Home / Scenarios / Community / Settings / Debug).
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Scenarios'), findsWidgets);
      expect(find.text('Community'), findsWidgets);
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Debug'), findsWidgets);
    });

    testWidgets('Scenarios tab lists the searchable scenario cards', (
      tester,
    ) async {
      await startToShell(tester);

      await tester.tap(find.text('Scenarios').first);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(
        find.bySemanticsIdentifier('scenarios-search-input'),
        findsOneWidget,
      );
      // A pre-existing card (top of the list) + a chunk #14/#17 card further
      // down — proving the new scenarios are registered.
      expect(
        find.bySemanticsIdentifier('scenarios-connection-card'),
        findsOneWidget,
      );
    });

    testWidgets('Scenarios search filters the list', (tester) async {
      await startToShell(tester);
      await tester.tap(find.text('Scenarios').first);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.enterText(
        find.bySemanticsIdentifier('scenarios-search-input'),
        'Initial Screen',
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // The matching card stays; a non-matching one is filtered out.
      expect(
        find.bySemanticsIdentifier('scenarios-initialScreen-card'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('scenarios-connection-card'),
        findsNothing,
      );
    });

    testWidgets('Opening a pure-Flutter scenario renders its scaffold', (
      tester,
    ) async {
      await startToShell(tester);
      await tester.tap(find.text('Scenarios').first);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Connection is a pure-Flutter scenario (no PlatformView) so it settles.
      await tester.tap(find.bySemanticsIdentifier('scenarios-connection-card'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // ScenarioScaffold renders the result panel for the catalog id at the
      // BOTTOM of its ListView (after description + Live state card + the
      // 5 preset buttons), so on CI device viewports the panel is below the
      // fold and `find.bySemanticsIdentifier` can't reach an unlaid widget.
      // Scroll the scaffold's ListView (anchored on the always-on-screen
      // first preset button — `.first` over all Scrollables is non-
      // deterministic when previous routes are still mounted under the
      // Navigator) until the result panel renders.
      final result = find.bySemanticsIdentifier('connection-result');
      // Same scoping concern as `startToShell`: `ListView` IS itself a
      // `Scrollable`, so the ancestor chain matches multiple widgets;
      // `.first` over the ancestor chain is the innermost match.
      await tester.scrollUntilVisible(
        result,
        200,
        scrollable: find
            .ancestor(
              of: find.bySemanticsIdentifier('qa-preset-connection-1'),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(result, findsOneWidget);

      // Back to the scenario list.
      await tester.pageBack();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(
        find.bySemanticsIdentifier('scenarios-search-input'),
        findsOneWidget,
      );
    });

    testWidgets('Settings tab renders its body', (tester) async {
      await startToShell(tester);
      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      // Assert a unique Settings *body* anchor — not the persistent bottom-nav
      // 'Settings' label (which is present on every tab and would make this a
      // tautology). 'Reset configuration' only exists in the Settings body.
      expect(find.text('Reset configuration'), findsOneWidget);
    });

    testWidgets('Debug tab renders the live-state console', (tester) async {
      await startToShell(tester);
      await tester.tap(find.text('Debug').first);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // The Debug tab's copy + clear affordances are always present.
      expect(
        find.bySemanticsIdentifier('debug-tab-copy-button'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('debug-tab-clear-button'),
        findsOneWidget,
      );
    });
  });
}
