import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/scenarios/content_options_scenario.dart';
import 'package:octopus_sdk_flutter_example/scenarios/profile_fields_lock_scenario.dart';
import 'package:octopus_sdk_flutter_example/scenarios/terms_acceptance_scenario.dart';

/// The three debug-override scenarios must expose, at runtime, exactly the test
/// ids the shared QA scenario catalog declares — the QA pipeline resolves
/// them up front, from a clean state, before any preset has run. The `-clear`
/// preset is the one that regresses silently: hiding it while there is nothing
/// to clear (the obvious UX reflex) breaks a teardown that has never applied an
/// override, so it is asserted from a freshly mounted screen like the others.
void main() {
  const cases = <String, ({Widget screen, List<String> presets})>{
    'profileFieldsLock': (
      screen: ProfileFieldsLockScenario(),
      presets: [
        'qa-preset-profileFieldsLock-1',
        'qa-preset-profileFieldsLock-2',
        'qa-preset-profileFieldsLock-3',
        'qa-preset-profileFieldsLock-clear',
      ],
    ),
    'contentOptions': (
      screen: ContentOptionsScenario(),
      presets: [
        'qa-preset-contentOptions-1',
        'qa-preset-contentOptions-2',
        'qa-preset-contentOptions-3',
        'qa-preset-contentOptions-4',
        'qa-preset-contentOptions-5',
        'qa-preset-contentOptions-6',
        'qa-preset-contentOptions-clear',
      ],
    ),
    'termsAcceptance': (
      screen: TermsAcceptanceScenario(),
      presets: [
        'qa-preset-termsAcceptance-1',
        'qa-preset-termsAcceptance-2',
        'qa-preset-termsAcceptance-3',
        'qa-preset-termsAcceptance-clear',
      ],
    ),
  };

  cases.forEach((id, spec) {
    testWidgets('$id exposes every catalog test id on a clean mount', (
      tester,
    ) async {
      // The scenario frame is a scrolling column: a default 800x600 viewport
      // never builds the presets below the fold, and an id that is merely
      // off-screen would fail for the wrong reason.
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // A bare AppState is enough: these screens read AppScope only when a
      // preset runs (and for the breadcrumb posted after the first frame),
      // never to build.
      await tester.pumpWidget(
        AppScope(
          state: AppState(),
          child: MaterialApp(home: spec.screen),
        ),
      );
      await tester.pump();

      for (final preset in spec.presets) {
        expect(
          find.bySemanticsIdentifier(preset),
          findsOneWidget,
          reason: '$preset is a catalog preset id and must resolve',
        );
      }
      expect(
        find.bySemanticsIdentifier('$id-result'),
        findsOneWidget,
        reason: 'the catalog result_test_id must resolve',
      );
    });
  });
}
