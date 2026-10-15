import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/branding.dart';
import 'package:octopus_sdk_flutter_example/design.dart';

void main() {
  for (final scroll in ['jump', 'animate', 'fling']) {
    testWidgets('expanded bar restores after $scroll returns to top', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: SampleScaffold(
            appBar: const SampleTopAppBar(
              title: 'Scenario',
              size: SampleTopBarSize.medium,
            ),
            body: ListView(
              controller: controller,
              children: const [SizedBox(height: 2400)],
            ),
          ),
        ),
      );
      final expanded = tester.getSize(find.byType(AppBar)).height;
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AppBar)).height, lessThan(expanded));
      expect(controller.position.extentBefore, greaterThan(0));
      if (scroll == 'jump') {
        controller.jumpTo(0);
      } else if (scroll == 'animate') {
        final animation = controller.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        await tester.pumpAndSettle();
        await animation;
      } else {
        // The finger stops short of the top; only the ballistic scroll reaches it.
        await tester.fling(find.byType(ListView), const Offset(0, 100), 2500);
        expect(controller.position.extentBefore, greaterThan(0));
        expect(tester.getSize(find.byType(AppBar)).height, lessThan(expanded));
      }
      await tester.pumpAndSettle();
      expect(controller.position.extentBefore, 0);
      expect(tester.getSize(find.byType(AppBar)).height, expanded);
      expect(tester.takeException(), isNull);
    });
  }
  for (final brightness in Brightness.values) {
    testWidgets('$brightness flat page and transparent app bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness),
          home: const SampleScaffold(
            appBar: SampleTopAppBar(title: 'Title'),
            body: SizedBox.expand(),
          ),
        ),
      );
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(AppBar),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, Colors.transparent);
      final theme = Theme.of(tester.element(find.byType(Scaffold)));
      expect(
        theme.scaffoldBackgroundColor,
        brightness == Brightness.dark
            ? sampleDarkSurface
            : sampleLightBackground,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('expanded title clears status inset and grows for large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(390, 900),
            padding: EdgeInsets.only(top: 40),
            textScaler: TextScaler.linear(2),
          ),
          child: SampleScaffold(
            appBar: SampleTopAppBar(
              title: 'A long scenario title that wraps',
              size: SampleTopBarSize.medium,
            ),
            body: SizedBox.expand(),
          ),
        ),
      ),
    );
    expect(
      tester.getTopLeft(find.text('A long scenario title that wraps')).dy,
      greaterThanOrEqualTo(40),
    );
    expect(
      tester.getSize(find.text('A long scenario title that wraps')).height,
      greaterThan(72),
    );
    expect(tester.takeException(), isNull);
  });
}
