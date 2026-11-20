import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/scenarios/connection_scenario.dart';
import 'package:octopus_sdk_flutter_example/scenarios/keyboard_mount_page.dart';
import 'package:octopus_sdk_flutter_example/widgets/scenario_scaffold.dart';

class _SDK extends OctopusSDK {
  String? subject;
  String? suppliedToken;

  @override
  Future<OctopusResult<void, ClientUserError>> connectUser({
    required String userId,
    required Future<String> Function() tokenProvider,
    String? nickname,
    String? bio,
    String? picture,
  }) async {
    subject = userId;
    suppliedToken = await tokenProvider();
    return OctopusInvalidArguments<ClientUserError>(const [
      ClientUserInvalidTokenError('Malformed token'),
    ]);
  }
}

class _App extends AppState {
  final sdk = _SDK();
  @override
  OctopusSDK get octopus => sdk;
  @override
  bool get initialized => true;
}

void main() {
  testWidgets(
    'malformed-token preset uses a synthetic identity and shows refusal',
    (tester) async {
      final app = _App();
      addTearDown(app.dispose);
      await tester.pumpWidget(
        AppScope(
          state: app,
          child: const MaterialApp(home: ConnectionScenario()),
        ),
      );
      final preset = tester
          .widget<ScenarioScaffold>(find.byType(ScenarioScaffold))
          .presets
          .singleWhere((p) => p.testId == 'qa-preset-connection-invalid-token');
      String? message;
      bool? failed;
      await preset.onRun((value, {bool isError = false}) {
        message = value;
        failed = isError;
      });
      expect(app.sdk.subject, 'demo-invalid-token');
      expect(app.sdk.suppliedToken, 'not-a-jwt');
      expect(
        message,
        'connectUser refused: ClientUserInvalidToken: Malformed token',
      );
      expect(failed, isTrue);
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform keyboard preset waits for the IME before mounting', (
      tester,
    ) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var creations = 0;
      messenger.setMockStreamHandler(
        const EventChannel('octopus_sdk_flutter/events'),
        MockStreamHandler.inline(onListen: (_, _) {}),
      );
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'resize') {
          final args = call.arguments as Map;
          return {'width': args['width'], 'height': args['height']};
        }
        if (call.method == 'create') {
          creations++;
          final id = (call.arguments as Map)['id'];
          messenger.setMockMethodCallHandler(
            MethodChannel('octopus_sdk_flutter/native_view/$id'),
            (_) async => null,
          );
          return 0;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        ),
      );
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.reset);
      debugDefaultTargetPlatformOverride = platform;
      try {
        await tester.pumpWidget(const MaterialApp(home: KeyboardMountPage()));
        await tester.pumpAndSettle();
        expect(find.byType(OctopusHomeScreen), findsNothing);
        expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNull,
        );
        await tester.showKeyboard(find.byType(TextField));
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mount community'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
          isTrue,
        );
        expect(find.byType(OctopusHomeScreen), findsOneWidget);
        expect(
          find.textContaining('At mount: keyboard 300.0, safe area 0.0.'),
          findsOneWidget,
        );
        expect(creations, 1);
        final surface = tester.element(find.byType(OctopusHomeScreen));
        tester.testTextInput.hide();
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        expect(tester.element(find.byType(OctopusHomeScreen)), same(surface));
        expect(creations, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
