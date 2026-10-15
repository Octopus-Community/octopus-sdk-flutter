import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/branding.dart';
import 'package:octopus_sdk_flutter_example/design.dart';
import 'package:octopus_sdk_flutter_example/main.dart';

/// Sample chrome uses the flat page ground on each tab.
void main() {
  void flatGround(WidgetTester tester) {
    final theme = Theme.of(tester.element(find.byType(SampleScaffold)));
    expect(theme.scaffoldBackgroundColor, sampleDarkSurface);
  }

  testWidgets('dark: flat ground on Scenarios and Community', (tester) async {
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
    flatGround(tester);

    await tester.tap(find.text('Community').last);
    await tester.pump();
    flatGround(tester);

    await tester.tap(find.text('Scenarios').last);
    await tester.pumpAndSettle();
    flatGround(tester);
  });
}
