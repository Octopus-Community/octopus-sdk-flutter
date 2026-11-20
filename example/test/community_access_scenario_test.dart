import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/scenarios/community_access_scenario.dart';

class _SeededAppState extends AppState {
  bool? _access;

  @override
  bool? get hasAccess => _access;

  bool _hasReason = false;
  CommunityAccessDeniedReason? _reason;

  @override
  bool get hasAccessDeniedReason => _hasReason;

  @override
  CommunityAccessDeniedReason? get accessDeniedReason => _reason;

  void emitAccess(bool value) {
    _access = value;
    notifyListeners();
  }

  void emitReason(CommunityAccessDeniedReason? value) {
    _hasReason = true;
    _reason = value;
    notifyListeners();
  }
}

void main() {
  testWidgets('renders all three presets and reacts to live access updates', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final app = _SeededAppState();
    addTearDown(app.dispose);

    await tester.pumpWidget(
      AppScope(
        state: app,
        child: const MaterialApp(home: CommunityAccessScenario()),
      ),
    );
    await tester.pump();

    const labels = [
      'Override · grant access',
      'Override · deny access',
      'Track · has access',
    ];
    for (final (index, label) in labels.indexed) {
      expect(find.widgetWithText(OutlinedButton, label), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('qa-preset-communityAccess-${index + 1}'),
        findsOneWidget,
      );
    }
    expect(find.text('hasAccessToCommunity'), findsOneWidget);
    expect(find.text('communityAccessDeniedReason'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2));
    app.emitAccess(false);
    app.emitReason(CommunityAccessDeniedReason.accountBanned);
    await tester.pump();
    expect(find.text('false'), findsOneWidget);
    expect(find.text('accountBanned'), findsOneWidget);
    app.emitAccess(true);
    app.emitReason(null);
    await tester.pump();
    expect(find.text('true'), findsOneWidget);
    expect(find.text('null'), findsOneWidget);

    const channel = MethodChannel('octopus_sdk_flutter');
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return <String, Object>{'type': 'success'};
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    for (var index = 1; index <= 3; index++) {
      await tester.tap(
        find.bySemanticsIdentifier('qa-preset-communityAccess-$index'),
      );
      await tester.pumpAndSettle();
    }
    expect(calls.map((call) => call.method), [
      'overrideCommunityAccess',
      'overrideCommunityAccess',
      'trackCommunityAccess',
    ]);
    expect(calls.map((call) => call.arguments), [
      {'hasAccess': true},
      {'hasAccess': false},
      {'hasAccess': true},
    ]);
  });
}
