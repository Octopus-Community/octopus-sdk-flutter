import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/scenarios/groups_scenario.dart';
import 'package:octopus_sdk_flutter_example/widgets/scenario_scaffold.dart';

class _SeededAppState extends AppState {
  @override
  List<OctopusGroup> get groups => const [
    OctopusGroup(id: 'news', name: 'News'),
    OctopusGroup(id: 'discussion', name: 'Discussion', isFollowed: true),
    OctopusGroup(
      id: 'announcements',
      name: 'Announcements',
      isFollowed: true,
      canChangeFollowStatus: false,
    ),
  ];
}

Future<void> _pumpScenario(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final app = _SeededAppState();
  addTearDown(app.dispose);
  await tester.pumpWidget(
    AppScope(
      state: app,
      child: const MaterialApp(home: GroupsScenario()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders fetch preset and follow controls for editable groups', (
    tester,
  ) async {
    await _pumpScenario(tester);

    expect(find.bySemanticsIdentifier('qa-preset-groups-1'), findsOneWidget);
    // Single presets use the shared frame's anchored "Run" button.
    final scaffold = tester.widget<ScenarioScaffold>(
      find.byType(ScenarioScaffold),
    );
    expect(scaffold.presets.single.label, 'Fetch groups');
    expect(find.text('News'), findsOneWidget);
    expect(find.text('Not followed'), findsOneWidget);
    expect(find.text('Followed'), findsNWidgets(2));
    expect(find.bySemanticsIdentifier('qa-groups-follow-news'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('qa-groups-unfollow-discussion'),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Follow'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Unfollow'), findsOneWidget);
    expect(find.text('Managed by server'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('qa-groups-unfollow-announcements'),
      findsNothing,
    );
  });

  testWidgets('only the pending row loads and each action sends its group id', (
    tester,
  ) async {
    const channel = MethodChannel('octopus_sdk_flutter');
    final pendingFollow = Completer<Map<String, Object>>();
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'followGroup') return pendingFollow.future;
      return <String, Object>{'type': 'success'};
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await _pumpScenario(tester);

    await tester.tap(find.bySemanticsIdentifier('qa-groups-follow-news'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final unfollow = find.widgetWithText(OutlinedButton, 'Unfollow');
    expect(tester.widget<OutlinedButton>(unfollow).onPressed, isNotNull);
    await tester.tap(unfollow);
    await tester.pump();

    expect(calls.map((call) => call.method), ['followGroup', 'unfollowGroup']);
    expect(calls[0].arguments, {'groupId': 'news'});
    expect(calls[1].arguments, {'groupId': 'discussion'});
    pendingFollow.complete({'type': 'success'});
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Follow'), findsOneWidget);
  });
}
