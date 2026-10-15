import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/branding.dart';
import 'package:octopus_sdk_flutter_example/design.dart';
import 'package:octopus_sdk_flutter_example/main.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('bars follow forced $brightness across tabs and routes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(top: 24, bottom: 32);
      tester.view.viewPadding = FakeViewPadding(top: 24, bottom: 32);
      tester.platformDispatcher.platformBrightnessTestValue =
          brightness == Brightness.dark ? Brightness.light : Brightness.dark;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final app = AppState();
      addTearDown(app.dispose);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        AppScope(
          state: app,
          child: MaterialApp(
            navigatorKey: navigator,
            theme: buildAppTheme(Brightness.light),
            darkTheme: buildAppTheme(Brightness.dark),
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            builder: (context, child) =>
                octopusDemoAppBuilderWith(context, child, showWarning: false),
            home: MainScreen(app: app),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final icons = brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark;
      expect(SystemChrome.latestStyle!.statusBarIconBrightness, icons);
      expect(
        SystemChrome.latestStyle!.systemNavigationBarIconBrightness,
        icons,
      );
      expect(
        SystemChrome.latestStyle!.systemNavigationBarColor,
        sampleSurface2For(brightness),
      );
      expect(
        SystemChrome.latestStyle!.systemNavigationBarContrastEnforced,
        false,
      );

      await tester.tap(find.text('Community').last);
      await tester.pump();
      expect(SystemChrome.latestStyle!.statusBarIconBrightness, icons);
      expect(SystemChrome.latestStyle!.statusBarBrightness, brightness);
      final safeArea = tester.widget<SafeArea>(
        find
            .ancestor(
              of: find.byType(CircularProgressIndicator),
              matching: find.byType(SafeArea),
            )
            .first,
      );
      expect(safeArea.top, true);
      final body = tester.getRect(find.byType(CircularProgressIndicator));
      expect(body.top, greaterThan(24));

      // Same Scaffold/SafeArea shape as fullscreen and modal SDK routes.
      navigator.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: SafeArea(bottom: false, child: SizedBox.expand()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(SystemChrome.latestStyle!.statusBarIconBrightness, icons);
      expect(
        SystemChrome.latestStyle!.systemNavigationBarIconBrightness,
        icons,
      );
      expect(
        SystemChrome.latestStyle!.systemNavigationBarColor,
        buildAppTheme(brightness).scaffoldBackgroundColor,
      );
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Scenarios').last);
      await tester.pumpAndSettle();
      expect(SystemChrome.latestStyle!.statusBarIconBrightness, icons);
    });
  }
}
