import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/branding.dart';
import 'package:octopus_sdk_flutter_example/design.dart';

Future<void> pump(
  WidgetTester tester,
  Widget body, {
  Brightness brightness = Brightness.light,
  double scale = 1,
  Widget? dock,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(brightness),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 900),
          textScaler: TextScaler.linear(scale),
          padding: const EdgeInsets.only(bottom: 24),
        ),
        child: SampleScaffold(body: body, bottomNavigationBar: dock),
      ),
    ),
  );
}

void main() {
  testWidgets('tinted blocks support interactive ListTile-family controls', (
    tester,
  ) async {
    var taps = 0;
    await pump(
      tester,
      SampleScenarioBlock(
        title: 'Try it',
        child: Column(
          children: [
            ListTile(title: const Text('Outer control'), onTap: () => taps++),
            SamplePanel(
              child: ListTile(
                title: const Text('Panel control'),
                onTap: () => taps++,
              ),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Outer control'));
    await tester.tap(find.text('Panel control'));
    await tester.pumpAndSettle();
    expect(taps, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'expanded app bars collapse on vertical scroll and restore at top',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: SampleScaffold(
            appBar: const SampleTopAppBar(
              title: 'Settings',
              size: SampleTopBarSize.large,
            ),
            body: ListView(
              controller: controller,
              children: const [SizedBox(height: 2000)],
            ),
          ),
        ),
      );
      final expanded = tester.getSize(find.byType(AppBar)).height;
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AppBar)).height, lessThan(expanded));
      await tester.drag(find.byType(ListView), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AppBar)).height, expanded);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('large-text choice initially reveals the persisted selection', (
    tester,
  ) async {
    await pump(
      tester,
      const Padding(
        padding: EdgeInsets.all(16),
        child: SampleSegmentedChoice<bool>(
          options: [(true, 'Octopus navy'), (false, 'SDK default')],
          selected: false,
          onChanged: null,
        ),
      ),
      scale: 2,
    );
    await tester.pumpAndSettle();
    final selected = tester.getRect(
      find.widgetWithText(ChoiceChip, 'SDK default'),
    );
    expect(selected.left, greaterThanOrEqualTo(16));
    expect(selected.right, lessThanOrEqualTo(374));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'barely scrollable content keeps its title collapsed after resize',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: SampleScaffold(
            appBar: const SampleTopAppBar(
              title: 'Scenario',
              size: SampleTopBarSize.medium,
            ),
            body: ListView(children: const [SizedBox(height: 818)]),
          ),
        ),
      );
      expect(tester.getSize(find.byType(AppBar)).height, 112);
      await tester.drag(find.byType(ListView), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AppBar)).height, 64);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getSize(find.byType(AppBar)).height, 64);
      await tester.drag(find.byType(ListView), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AppBar)).height, 64);
      await tester.drag(find.byType(ListView), const Offset(0, 100));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AppBar)).height, 112);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('short summary values stay on one row and align to the right', (
    tester,
  ) async {
    await pump(
      tester,
      const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            SampleKeyValue('Name', 'Demo'),
            SampleKeyValue('Server', 'Demo server'),
          ],
        ),
      ),
    );
    expect(
      tester.getTopLeft(find.text('Name')).dy,
      tester.getTopLeft(find.text('Demo')).dy,
    );
    expect(tester.getTopRight(find.text('Demo')).dx, 374);
    expect(tester.getTopRight(find.text('Demo server')).dx, 374);
  });
  testWidgets('long summary values reflow according to their measured width', (
    tester,
  ) async {
    await pump(
      tester,
      const Padding(
        padding: EdgeInsets.all(16),
        child: SampleKeyValue(
          'Server environment',
          'A much longer server environment value',
        ),
      ),
      scale: 2,
    );
    expect(
      tester.getTopLeft(find.text('A much longer server environment value')).dy,
      greaterThan(tester.getTopLeft(find.text('Server environment')).dy),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('search has a 64dp target and reports edits', (tester) async {
    var value = '';
    await pump(tester, SampleSearchField(onChanged: (v) => value = v));
    expect(tester.getSize(find.byType(TextField)).height, 64);
    await tester.enterText(find.byType(TextField), 'connectUser');
    expect(value, 'connectUser');
  });
  testWidgets('summary navigation rows are full width with text at x56', (
    tester,
  ) async {
    var tapped = false;
    await pump(
      tester,
      Column(
        children: [
          SampleNavTile(
            icon: Icons.cloud_outlined,
            title: 'Configuration',
            onTap: () => tapped = true,
          ),
        ],
      ),
    );
    expect(tester.getTopLeft(find.text('Configuration')).dx, 56);
    expect(tester.getSize(find.byType(SampleNavTile)).height, 56);
    await tester.tap(find.text('Configuration'));
    expect(tapped, isTrue);
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      '$brightness selected switches use a white thumb and blue track',
      (tester) async {
        await pump(
          tester,
          const SampleSwitchRow(
            title: 'Callback',
            value: true,
            onChanged: null,
          ),
          brightness: brightness,
        );
        final theme = Theme.of(tester.element(find.byType(Switch)));
        expect(
          theme.switchTheme.thumbColor!.resolve({WidgetState.selected}),
          Colors.white,
        );
        expect(
          theme.switchTheme.trackColor!.resolve({WidgetState.selected}),
          sampleAccentBlue,
        );
      },
    );
    testWidgets(
      '$brightness action dock pins a visible 56dp capsule above the inset',
      (tester) async {
        await pump(
          tester,
          const SizedBox.expand(),
          brightness: brightness,
          dock: SampleActionBar(
            child: FilledButton(onPressed: () {}, child: const Text('Apply')),
          ),
        );
        final button = find.descendant(
          of: find.byType(FilledButton),
          matching: find.byType(Material),
        );
        expect(tester.getSize(button).height, 56);
        expect(tester.getBottomRight(button).dy, lessThanOrEqualTo(876));
      },
    );
    for (final scale in [1.0, 2.0]) {
      testWidgets('$brightness primitives fit at $scale text size', (
        tester,
      ) async {
        var selection = 'Light';
        var changes = 0;
        await pump(
          tester,
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const PlatformBadge(),
              const SampleScenarioBlock(
                title: 'Try it',
                child: SamplePanel(
                  child: SampleParameterRow(
                    name: 'count',
                    type: 'Int',
                    value: '3',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const SampleStatusBadge(
                status: SampleStatus.passed,
                label: 'Success · 124 ms',
              ),
              const SampleCodeBlock('OctopusSuccess(data: true)'),
              SampleSegmentedChoice<String>(
                options: const [('Light', 'Light'), ('Dark', 'Dark')],
                selected: selection,
                onChanged: (v) {
                  selection = v;
                  changes++;
                },
              ),
              SampleBand(
                tone: SampleTone.neutral,
                message: 'Force login is on',
                actionLabel: 'Change',
                onAction: () => changes++,
              ),
            ],
          ),
          brightness: brightness,
          scale: scale,
        );
        await tester.tap(find.text('Dark'));
        expect(selection, 'Dark');
        await tester.ensureVisible(find.text('Change'));
        await tester.tap(find.text('Change'));
        expect(changes, 2);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
