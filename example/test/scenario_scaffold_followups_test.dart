import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/branding.dart';
import 'package:octopus_sdk_flutter_example/design.dart';
import 'package:octopus_sdk_flutter_example/feature_toggles.dart';
import 'package:octopus_sdk_flutter_example/widgets/scenario_customize.dart';
import 'package:octopus_sdk_flutter_example/widgets/scenario_scaffold.dart';

class _App extends AppState {
  final sectionRequests = <String>[];

  @override
  void requestScenariosSection(String sectionId) {
    sectionRequests.add(sectionId);
    super.requestScenariosSection(sectionId);
  }
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('$brightness feature band has one accessible Change action', (
      tester,
    ) async {
      final app = _App();
      addTearDown(app.dispose);
      await tester.pumpWidget(
        AppScope(
          state: app,
          child: MaterialApp(
            theme: buildAppTheme(brightness),
            home: ScenarioSectionScope(
              sectionId: 'sso',
              featureToggle: FeatureToggle.forceLogin,
              child: ScenarioScaffold(
                title: 'Feature scenario',
                description: 'Try the feature',
                resultTestId: 'feature-result',
                presets: [
                  ScenarioPreset(
                    testId: 'feature-execute',
                    label: 'Execute',
                    onRun: (_) async {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final band = find.byType(SampleBand);
      final message = tester.widget<SampleBand>(band).message;
      final node = tester.getSemantics(
        find.bySemanticsIdentifier('scenario-feature-state'),
      );
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(node.label, contains(message));
      expect(node.label, contains('Change'));
      expect(
        find.ancestor(of: find.text(message), matching: find.byType(InkWell)),
        findsNothing,
      );
      await tester.tap(find.text(message));
      await tester.pumpAndSettle();
      expect(app.sectionRequests, isEmpty);
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      expect(app.sectionRequests, ['sso']);
      // Assistive technology invokes the same single action.
      tester
          .renderObject(band)
          .owner!
          .semanticsOwner!
          .performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(app.sectionRequests, ['sso', 'sso']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$brightness stale result has no Result heading', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = AppState();
      addTearDown(app.dispose);
      final holders = ScenarioCustomizeHolders();
      var value = 'first';
      await tester.pumpWidget(
        AppScope(
          state: app,
          child: MaterialApp(
            theme: buildAppTheme(brightness),
            home: StatefulBuilder(
              builder: (context, setState) => ScenarioScaffold(
                title: 'Editable scenario',
                description: 'Try a value',
                resultTestId: 'editable-result',
                presets: [
                  ScenarioPreset(
                    testId: 'editable-execute',
                    label: 'Preset 1',
                    onRun: (result) async => result('Completed with $value'),
                  ),
                  ScenarioPreset(
                    testId: 'editable-second',
                    label: 'Preset 2',
                    onRun: (result) async => result('Completed with $value'),
                  ),
                ],
                customize: ScenarioCustomize(
                  holders: holders,
                  params: [
                    ScenarioEditableParam(
                      name: 'value',
                      type: 'String',
                      help: '',
                      presetValues: const ['first', 'second'],
                      value: value,
                      onValueChange: (next) => setState(() => value = next),
                    ),
                  ],
                  replacesCatalogParams: const {'value'},
                  customRun: (result) async => result('Completed with $value'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.bySemanticsIdentifier('editable-execute'));
      await tester.pumpAndSettle();
      expect(find.text('Completed with first'), findsOneWidget);
      await tester.tap(find.text('Customize ›'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'second');
      await tester.pumpAndSettle();
      expect(find.text('Not run yet — values changed'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('scenario-result-idle'),
        findsOneWidget,
      );
      expect(find.text('Completed with first'), findsNothing);
      expect(find.text('Result'), findsNothing);
      await tester.enterText(find.byType(TextFormField), 'first');
      await tester.pumpAndSettle();
      expect(find.text('Completed with first'), findsOneWidget);
      expect(find.text('Not run yet — values changed'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
