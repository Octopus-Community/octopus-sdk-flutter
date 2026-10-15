import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('octopus_sdk_flutter');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  for (final unsupported in [false, true]) {
    test('refreshCommunityConfig catches a malformed channel response after '
        '${unsupported ? 'an unsupported read' : 'a valid config'}', () async {
      SharedPreferences.setMockInitialValues({});
      Object response = {'exposeClientUserId': true};
      var reads = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method != 'debugGetCommunityConfig') return null;
        reads++;
        if (response is PlatformException) {
          throw response;
        }
        return response;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final app = AppState();
      addTearDown(app.dispose);
      await app.start(
        const DemoConfig(
          apiKeySource: ApiKeySource.custom,
          customApiKey: 'fixture-only',
          userId: 'test-user',
          theme: AppThemeChoice.system,
          serverEnv: ServerEnv.prod,
        ),
      );
      expect(app.initialized, isTrue);
      expect(app.initError, isNull);
      expect(app.communityConfig?.exposeClientUserId, isTrue);
      expect(app.exposeClientUserIdSummary, 'on · Use backend value');

      if (unsupported) {
        response = PlatformException(code: 'UNSUPPORTED_PLATFORM');
        await app.refreshCommunityConfig();
        expect(app.communityConfigReadable, isFalse);
        expect(
          app.exposeClientUserIdSummary,
          'unreadable here · Use backend value',
        );
      }

      // A successful envelope with the wrong wire type throws a TypeError
      // inside invokeMethod, beyond the PlatformException-only handler.
      response = 'malformed config';
      await expectLater(
        app.octopus.debugGetCommunityConfig(),
        throwsA(isA<TypeError>()),
      );
      var notifications = 0;
      app.addListener(() => notifications++);
      final previousReads = reads;
      await expectLater(app.refreshCommunityConfig(), completes);
      expect(reads, previousReads + 1);
      expect(app.communityConfig, isNull);
      expect(app.communityConfigReadable, isTrue);
      expect(app.exposeClientUserIdSummary, 'unknown · Use backend value');
      expect(notifications, 1);
    });
  }
}
