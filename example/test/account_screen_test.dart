import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/settings/account_screen.dart';

/// Account is a pushed route: nothing above it consumes the bottom system
/// inset the app shell's own `SafeArea` handles for the tabs. Without one of
/// its own, the list scrolls under Android's gesture handle, which crosses
/// whatever label rests there — the bottom session button, in the report —
/// and reads as a strikethrough (`#355`).
void main() {
  const inset = 48.0;
  const viewport = Size(400, 800);

  testWidgets('the list never scrolls under the bottom system inset', (
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
              child: const AccountScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // The viewport itself stops above the handle, so no scroll position can
    // put a label under it — asserting on one button's resting place would
    // only cover the scroll offset the test happens to leave it at.
    expect(
      tester.getRect(find.byType(ListView)).bottom,
      lessThanOrEqualTo(viewport.height - inset),
    );

    // The button the report named, still built and still reachable.
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'Connect SSO User');
    expect(button, findsOneWidget);
    expect(
      tester.getBottomLeft(button).dy,
      lessThanOrEqualTo(viewport.height - inset),
    );
  });
}
