import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/auth/profile_edit_page.dart';
import 'package:octopus_sdk_flutter_example/debug/debug_log.dart';
import 'package:octopus_sdk_flutter_example/debug/events_log_screen.dart';
import 'package:octopus_sdk_flutter_example/widgets/scenario_scaffold.dart';

/// These pushed routes sit outside the app shell's SafeArea, just like the
/// Settings routes covered by settings_pushed_routes_test.dart.
void main() {
  const inset = 48.0;
  const viewport = Size(400, 800);

  final routes = <String, Widget>{
    'Events log': const EventsLogScreen(),
    'Edit profile': const ProfileEditPage(),
    for (final count in [1, 3])
      'Scenario with $count presets': ScenarioScaffold(
        title: 'Safe area scenario',
        description: 'Check the scenario body and preset buttons.',
        resultTestId: 'safe-area-result',
        hidesResult: true,
        liveState: const SizedBox(height: 700),
        presets: [
          for (var i = 1; i <= count; i++)
            ScenarioPreset(
              testId: 'qa-preset-safe-area-$i',
              label: 'Preset $i',
              onRun: (_) async {},
            ),
        ],
      ),
  };

  for (final MapEntry(key: name, value: screen) in routes.entries) {
    testWidgets('$name never scrolls under the bottom system inset', (
      tester,
    ) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      if (screen is EventsLogScreen) {
        debugLog.clear();
        addTearDown(debugLog.clear);
        // An empty log renders a placeholder instead of the scrollable list.
        for (var i = 0; i < 30; i++) {
          debugLog.note('Test event $i');
        }
      }

      await tester.pumpWidget(
        AppScope(
          state: AppState(),
          child: MaterialApp(
            home: Builder(
              builder: (context) => MediaQuery(
                // A phone in gesture navigation, as in the Settings tests.
                data: MediaQuery.of(
                  context,
                ).copyWith(padding: const EdgeInsets.only(bottom: inset)),
                child: screen,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // The viewport itself stops above the handle, so no scroll position can
      // put a row under it.
      expect(
        tester.getRect(find.byType(Scrollable).first).bottom,
        lessThanOrEqualTo(viewport.height - inset),
      );

      if (screen is ScenarioScaffold) {
        if (screen.presets.length == 1) {
          final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
          // Scaffold removes the body's bottom padding when the anchored bar
          // is present: the new body SafeArea must not add a second inset.
          expect(
            tester.getRect(find.byType(Scrollable).first).bottom,
            tester.getRect(find.byWidget(scaffold.bottomNavigationBar!)).top,
          );
          expect(
            tester
                .getBottomLeft(find.widgetWithText(FilledButton, 'Execute'))
                .dy,
            lessThanOrEqualTo(viewport.height - inset),
          );
        } else {
          final button = find.widgetWithText(OutlinedButton, 'Preset 3');
          await tester.scrollUntilVisible(
            button,
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(button, findsOneWidget);
          expect(
            tester.getBottomLeft(button).dy,
            lessThanOrEqualTo(viewport.height - inset),
          );
          expect(button.hitTestable(), findsOneWidget);
        }
      }
    });
  }
}
