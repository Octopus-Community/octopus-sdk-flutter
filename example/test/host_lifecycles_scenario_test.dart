import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/scenarios/host_lifecycles_scenario.dart';

import 'sample_shell_test.dart' show pumpShell;

class _App extends AppState {
  bool ready = true;
  @override
  bool get initialized => ready;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  final created = <int>[];
  final disposed = <int>[];
  final params = <Map>[];
  final visibility = <int, List<bool>>{};

  setUp(() {
    created.clear();
    disposed.clear();
    params.clear();
    visibility.clear();
    messenger.setMockStreamHandler(
      const EventChannel('octopus_sdk_flutter/events'),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('octopus_sdk_flutter'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      final args = call.arguments;
      if (call.method == 'create') {
        final map = args as Map;
        final id = map['id'] as int;
        created.add(id);
        visibility[id] = [];
        params.add(
          const StandardMessageCodec().decodeMessage(
                ByteData.sublistView(map['params'] as Uint8List),
              )
              as Map,
        );
        messenger.setMockMethodCallHandler(
          MethodChannel('octopus_sdk_flutter/native_view/$id'),
          (call) async {
            if (call.method == 'setVisible') {
              visibility[id]!.add(call.arguments as bool);
            }
            return null;
          },
        );
        return debugDefaultTargetPlatformOverride == TargetPlatform.android
            ? created.length
            : null;
      }
      if (call.method == 'dispose') {
        disposed.add(args is Map ? args['id'] as int : args as int);
      }
      if (call.method == 'resize') {
        final map = args as Map;
        return {'width': map['width'], 'height': map['height']};
      }
      return null;
    });
  });

  tearDown(() {
    for (final id in created) {
      messenger.setMockMethodCallHandler(
        MethodChannel('octopus_sdk_flutter/native_view/$id'),
        null,
      );
    }
    messenger.setMockStreamHandler(
      const EventChannel('octopus_sdk_flutter/events'),
      null,
    );
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('octopus_sdk_flutter'),
      null,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final presetNumber in [3, 6]) {
      final keepMounted = presetNumber == 6;
      testWidgets('$platform preset $presetNumber counts three completed returns', (
        tester,
      ) async {
        // testWidgets owns the semantics handle (semanticsEnabled defaults true).
        debugDefaultTargetPlatformOverride = platform;
        await pumpShell(
          tester,
          state: _App(),
          platform: platform,
          home: const HostLifecyclesScenario(),
        );
        final result = find.bySemanticsIdentifier('hostLifecycles-result');
        String resultText() {
          // Widget finders can still find nodes excluded by BlockSemantics.
          // Device QA reads the actual attached accessibility tree instead.
          final nodes = find.semantics.byPredicate(
            (node) => node.identifier == 'hostLifecycles-result',
          );
          expect(nodes.evaluate(), hasLength(1));
          return nodes.evaluate().single.label;
        }

        Future<void> start() async {
          final preset = find.bySemanticsIdentifier(
            'qa-preset-hostLifecycles-$presetNumber',
          );
          await tester.ensureVisible(preset);
          await tester.tap(preset);
          await tester.pumpAndSettle();
        }

        expect(resultText(), 'Not run yet');
        await start();
        expect(resultText(), 'Running…'); // Initial appearance is not a return.
        expect(created, hasLength(1));
        final firstId = created.single;
        final expectedVisibility = [true];
        for (var cycle = 1; cycle <= 3; cycle++) {
          final oldId = created.last;
          await tester.tap(find.text('Push host screen'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          // Neither mode blanks the community during the incoming transition.
          expect(
            find.byType(OctopusHomeScreen, skipOffstage: false),
            findsOneWidget,
          );
          expect(disposed, isNot(contains(oldId)));
          await tester.pumpAndSettle();
          expect(result, findsOneWidget);
          expect(resultText(), 'Running…');
          expect(
            find.byType(OctopusHomeScreen, skipOffstage: false),
            keepMounted ? findsOneWidget : findsNothing,
          );
          if (keepMounted) {
            expect(created, [firstId]);
            expect(disposed, isEmpty);
            if (platform == TargetPlatform.android) {
              expectedVisibility.add(false);
              expect(visibility[firstId], expectedVisibility);
            }
          } else {
            expect(disposed, contains(oldId));
          }

          if (cycle == 2) {
            await binding.handlePopRoute(); // Android Back / system pop.
          } else {
            await tester.tap(find.text('Pop host screen'));
          }
          await tester.pump();
          expect(
            resultText(),
            'Running…',
          ); // Reverse transition still in flight.
          await tester.pumpAndSettle();
          expect(resultText(), startsWith('Returned $cycle time(s)…'));
          expect(resultText(), isNot(contains('PASS')));
          expect(result, findsOneWidget);
          if (keepMounted) {
            // An equal widget configuration is insufficient: native ids must match.
            expect(created, [firstId]);
            expect(disposed, isEmpty);
            if (platform == TargetPlatform.android) {
              expectedVisibility.add(true);
              expect(visibility[firstId], expectedVisibility);
            }
          } else {
            expect(created, hasLength(cycle + 1));
            expect(created.last, isNot(oldId));
          }
          expect(params.last['initialScreen'], params.first['initialScreen']);
          await tester.pump(const Duration(seconds: 1));
          expect(resultText(), startsWith('Returned $cycle time(s)…'));
        }
        await tester.tap(find.text('Back to scenario'));
        await tester.pumpAndSettle();
        expect(resultText(), startsWith('Returned 3 time(s)…'));
        await start();
        expect(resultText(), 'Running…');
        await tester.tap(find.text('Push host screen'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pop host screen'));
        await tester.pumpAndSettle();
        expect(resultText(), startsWith('Returned 1 time(s)…'));
        tester
            .widget<OctopusHomeScreen>(find.byType(OctopusHomeScreen))
            .onBack!();
        await tester.pumpAndSettle();
        expect(find.byType(OctopusHomeScreen), findsNothing);
        expect(resultText(), startsWith('Returned 1 time(s)…'));
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }

  testWidgets('blank post cannot start a native view', (tester) async {
    await pumpShell(
      tester,
      state: _App(),
      home: const HostLifecyclesScenario(),
    );
    await tester.enterText(find.byType(TextField), '   ');
    final preset = find.bySemanticsIdentifier('qa-preset-hostLifecycles-3');
    await tester.ensureVisible(preset);
    await tester.tap(preset);
    await tester.pumpAndSettle();
    expect(
      find.text('Initialize a demo community and enter a Post ID.'),
      findsOneWidget,
    );
    expect(created, isEmpty);
  });
}
