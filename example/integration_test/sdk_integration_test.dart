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
///     pure-Flutter tabs (Home / Scenarios / Settings). Debug is not a tab
///     (D1, cadrage report 07) — the Events log is a screen reached from
///     Settings → Developer tools via `debug-open-button`.
///  2. Scenario presets are exercised for "does not throw / renders a result"
///     only — we assert the result panel appears, not its backend-dependent
///     text.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Boots the app and taps through the Config screen so the bottom-nav shell
  /// is mounted. Leaves the harness on the Home tab.
  ///
  /// Auto-restore note: the sample persists its DemoConfig to
  /// `shared_preferences` and reloads it on launch, so a 2nd `app.main()` in
  /// the same integration_test session lands directly on the shell — the
  /// Config screen never re-appears. Tap-through only when it's actually
  /// there, otherwise the harness is already on the bottom-nav shell.
  Future<void> startToShell(WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final config = find.bySemanticsIdentifier('config-screen');
    if (config.evaluate().isNotEmpty) {
      // The User ID picker sits between the API-key picker and the theme
      // selector, pushing the Start button below the viewport on CI device
      // sizes. `find.bySemanticsIdentifier` doesn't see widgets
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
      // `scrollUntilVisible` stops as soon as the button PARTIALLY enters the
      // viewport. When no ProductionWarningBanner is shown — the case here,
      // since integration runs pin the demo host and inject no
      // --dart-define=OCTOPUS_INTERNAL=true (either one alone already hides
      // it; this run has neither) — the route spans the full screen height
      // and a half-visible button's center lands exactly on the screen edge —
      // outside the render tree, so `tap()` misses with a non-fatal warning
      // and the whole suite cascades. Bring it fully into view first
      // (unconditional: harmless on a run where the banner does render).
      await tester.ensureVisible(start);
      await tester.pumpAndSettle();
      expect(start, findsOneWidget);
      await tester.tap(start);
      // start() sets the DemoConfig and the root rebuilds to the shell
      // regardless of init success, so the shell appears even keyless.
      await tester.pumpAndSettle(const Duration(seconds: 5));
    }
  }

  group('Sample shell', () {
    testWidgets('Config → Start reveals all four bottom-nav tabs', (
      tester,
    ) async {
      await startToShell(tester);

      // The four-tab shell, in order (D1, cadrage report 07): Home /
      // Scenarios / Community / Settings. Debug is not a tab.
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Scenarios'), findsWidgets);
      expect(find.text('Community'), findsWidgets);
      expect(find.text('Settings'), findsWidgets);
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
      // tautology). Settings is now a pure summary of navigation rows, so the
      // anchor is the Account entry that opens it; Reset data moved down into
      // About, behind its own chevron.
      expect(
        find.bySemanticsIdentifier('settings-account-entry'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('settings-devtools-entry'),
        findsOneWidget,
      );
    });

    testWidgets('Events log opens from Settings → Developer tools', (
      tester,
    ) async {
      await startToShell(tester);
      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Developer tools is a Settings → Support row; the Events log lives
      // one level under it, still behind `debug-open-button`.
      final devTools = find.bySemanticsIdentifier('settings-devtools-entry');
      await tester.ensureVisible(devTools);
      await tester.pumpAndSettle();
      await tester.tap(devTools);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final openButton = find.bySemanticsIdentifier('debug-open-button');
      expect(openButton, findsOneWidget);
      await tester.tap(openButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // The log's copy + clear affordances are always present. Closing is now
      // a plain route pop — the console modal (and its close button) is gone.
      expect(find.bySemanticsIdentifier('debug-copy-button'), findsOneWidget);
      expect(find.bySemanticsIdentifier('debug-clear-button'), findsOneWidget);
      expect(find.bySemanticsIdentifier('debug-log-list'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle(const Duration(seconds: 1));
    });

    testWidgets(
      'Reset configuration lives in Settings, behind a confirmation',
      (tester) async {
        await startToShell(tester);
        await tester.tap(find.text('Settings').first);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Reset is the Support group's last, red row — it moved out of About
        // when Config absorbed the per-setting screens (#324).
        final resetTile = find.bySemanticsIdentifier('settings-reset-button');
        await tester.ensureVisible(resetTile);
        await tester.pumpAndSettle();
        expect(resetTile, findsOneWidget);

        // Open the confirmation and dismiss it — the destructive path itself is
        // not exercised here, only the guard in front of it.
        await tester.tap(resetTile);
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(
          find.bySemanticsIdentifier('settings-reset-confirm'),
          findsOneWidget,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle(const Duration(seconds: 1));
      },
    );
  });
}
