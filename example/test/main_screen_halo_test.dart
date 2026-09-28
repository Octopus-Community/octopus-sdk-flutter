import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/branding.dart';
import 'package:octopus_sdk_flutter_example/design.dart';
import 'package:octopus_sdk_flutter_example/main.dart';

/// The shell's wiring of the dark halo (`halo: !hasOwnAppBar` in
/// `MainScreen`), not just [SampleScaffold] on its own: the sample's tabs
/// paint it, the Community tab — the SDK's embedded view — does not.
void main() {
  Finder halo() => find.descendant(
    of: find.byType(SampleScaffold),
    matching: find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is SampleHaloPainter,
    ),
  );

  testWidgets('dark: halo on Home, none on Community, back on Home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = AppState();
    addTearDown(app.dispose);
    await tester.pumpWidget(
      AppScope(
        state: app,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: ThemeMode.dark,
          builder: (context, child) =>
              octopusDemoAppBuilderWith(context, child, showWarning: false),
          home: MainScreen(app: app),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(halo(), findsOneWidget);

    await tester.tap(find.text('Community').last);
    await tester.pump();
    expect(halo(), findsNothing);

    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    expect(halo(), findsOneWidget);
  });
}
