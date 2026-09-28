import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/sample_fixtures.dart';
import 'package:octopus_sdk_flutter_example/scenarios/fullscreen_scenario.dart';
import 'package:octopus_sdk_flutter_example/scenarios/modal_scenario.dart';
import 'package:octopus_sdk_flutter_example/scenarios/sheet_scenario.dart';
import 'package:octopus_sdk_flutter_example/widgets/scenario_scaffold.dart';

void main() {
  test('notification uses the selected post and rejects an empty override', () {
    const fixtures = SampleFixtures(postText: 'override-post');
    final notification = OctopusSDK.getOctopusNotification(
      fixtures.postNotificationPayload,
    )!;
    expect(notification.postId, 'override-post');
    expect(notification.linkPath, 'post/override-post');
    expect(
      () => const SampleFixtures(postText: '').postNotificationPayload,
      throwsStateError,
    );
  });

  test('topic fixture must belong to the active community', () {
    const fixtures = SampleFixtures(topicDefault: 'fixture-topic');
    const general = OctopusGroup(id: 'general', name: 'General');
    const fixture = OctopusGroup(id: 'fixture-topic', name: 'QA');
    expect(fixtures.defaultGroupId([general, fixture]), fixture.id);
    expect(fixtures.defaultGroupId([general]), general.id);
    expect(fixtures.defaultGroupId([]), isNull);
  });

  test('fixtures without a default stay absent', () {
    expect([
      sampleFixtures.postImage,
      sampleFixtures.postPoll,
      sampleFixtures.postCta,
      sampleFixtures.commentReported,
      sampleFixtures.topicGated,
      sampleFixtures.deeplinkPost,
    ], everyElement(isNull));
  });

  for (final scenario in <String, Widget>{
    'fullscreen': const FullscreenScenario(),
    'modal': const ModalScenario(),
    'sheet': const SheetScenario(),
  }.entries) {
    testWidgets('${scenario.key} preset passes post.text to the SDK view', (
      tester,
    ) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockStreamHandler(
        const EventChannel('octopus_sdk_flutter/events'),
        MockStreamHandler.inline(onListen: (_, _) {}),
      );
      final app = AppState();
      addTearDown(app.dispose);
      await tester.pumpWidget(
        AppScope(
          state: app,
          child: MaterialApp(home: scenario.value),
        ),
      );
      final scaffold = tester.widget<ScenarioScaffold>(
        find.byType(ScenarioScaffold),
      );
      final errors = <String>[];
      final opening = scaffold.presets
          .singleWhere(
            (preset) => preset.testId == 'qa-preset-${scenario.key}-2',
          )
          .onRun((text, {bool isError = false}) {
            if (isError) errors.add(text);
          });
      await tester.pumpAndSettle();
      final view = tester.widget<OctopusHomeScreen>(
        find.byType(OctopusHomeScreen),
      );
      expect(view.notification?.postId, sampleFixtures.postText);
      expect(view.notification?.linkPath, 'post/${sampleFixtures.postText}');
      Navigator.of(tester.element(find.byType(OctopusHomeScreen))).pop();
      await tester.pumpAndSettle();
      await opening;
      expect(errors, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
