import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/settings/about_screen.dart';
import 'package:octopus_sdk_flutter_example/settings/debug_info_screen.dart';
import 'package:octopus_sdk_flutter_example/settings/developer_tools_screen.dart';

/// The Settings routes pushed over the app shell — About, Debug info and
/// Developer tools — sit outside the shell's `SafeArea`, exactly like Account
/// (`account_screen_test.dart`, #355). Each one needs an inset of its own, or
/// its list scrolls under Android's gesture handle and the handle crosses
/// whatever label rests at the bottom (#359).
///
/// The Settings tab itself is not in this list on purpose: the shell already
/// insets every tab, so a `SafeArea` there would be a no-op.
void main() {
  const inset = 48.0;
  const viewport = Size(400, 800);

  const routes = <String, Widget>{
    'About': AboutScreen(),
    'Debug info': DebugInfoScreen(),
    'Developer tools': DeveloperToolsScreen(),
  };

  for (final MapEntry(key: name, value: screen) in routes.entries) {
    testWidgets('$name never scrolls under the bottom system inset', (
      tester,
    ) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        AppScope(
          state: AppState(),
          child: MaterialApp(
            home: Builder(
              builder: (context) => MediaQuery(
                // A phone in gesture navigation, which is what the defect was
                // reported on.
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
        tester.getRect(find.byType(ListView)).bottom,
        lessThanOrEqualTo(viewport.height - inset),
      );
    });
  }
}
