import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';
import 'package:octopus_sdk_flutter_example/app_state.dart';
import 'package:octopus_sdk_flutter_example/app_log.dart';
import 'package:octopus_sdk_flutter_example/debug/debug_log.dart';
import 'package:octopus_sdk_flutter_example/octopus_demo_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Invoked explicitly by create_client_user_token_test.dart with generated
// dart-defines. This filename avoids discovery by the ordinary test suite.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'real AppState token provider uses the compiled token configuration',
    () async {
      expect(
        const bool.hasEnvironment('EXPECT_SSO_SIGNING'),
        isTrue,
        reason: 'The fixture requires an explicit SSO signing mode.',
      );
      expect(
        hasInjectedSsoSecret,
        const bool.fromEnvironment('EXPECT_SSO_SIGNING'),
        reason:
            'The injected SSO secret must match the requested signing mode.',
      );
      expect(octopusApiKey, isEmpty);
      expect(octopusUserToken, startsWith('test-only-'));
      if (hasInjectedSsoSecret) {
        expect(octopusSsoClientUserTokenSecret, startsWith('test-only-'));
      }
      SharedPreferences.setMockInitialValues({});
      const channel = MethodChannel('octopus_sdk_flutter');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      late Map connectArguments;
      var nativeConnectCalled = false;
      late Completer<String> tokenReply;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'connectUser') {
          nativeConnectCalled = true;
          connectArguments = call.arguments as Map;
        } else if (call.method == 'provideClientUserToken') {
          tokenReply.complete((call.arguments as Map)['token'] as String);
        }
        return {'type': 'success'};
      });
      messenger.setMockStreamHandler(
        const EventChannel('octopus_sdk_flutter/events'),
        MockStreamHandler.inline(onListen: (_, _) {}),
      );
      final app = AppState();
      final previousLog = demoLog;
      final log = RealDebugLog();
      demoLog = log;
      addTearDown(() async {
        demoLog = previousLog;
        log.dispose();
        await app.octopus.stop();
        app.dispose();
        messenger.setMockMethodCallHandler(channel, null);
        messenger.setMockStreamHandler(
          const EventChannel('octopus_sdk_flutter/events'),
          null,
        );
      });

      final result = await app.connectDemoUser(entitlements: {'premium'});
      const mode = String.fromEnvironment('EXPECT_DEMO_TOKEN_MODE');
      if (mode == 'expired') {
        expect(result, isA<OctopusInvalidArguments<ClientUserError>>());
        expect(nativeConnectCalled, isFalse);
        expect(
          app.lastConnectError,
          contains("This build's demo tokens expired"),
        );
        expect(
          log.entries.single.label,
          contains("This build's demo tokens expired"),
        );
        return;
      }
      expect(result, isA<OctopusSuccess<void, ClientUserError>>());
      final providerId = connectArguments['providerId'];
      expect(providerId, isNotNull);
      expect(connectArguments['userId'], app.effectiveUserId);

      Future<void> expectToken(
        String requestId,
        List<String> entitlements,
      ) async {
        tokenReply = Completer<String>();
        final earliestExpiry =
            DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
        OctopusSDK.handleNativeEvent({
          'event': 'clientUserTokenRequest',
          'providerId': providerId,
          'requestId': requestId,
        });
        final token = await tokenReply.future.timeout(
          const Duration(seconds: 5),
        );
        final latestExpiry =
            DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
        if (mode == 'presigned') {
          final tokens = jsonDecode(octopusDemoUserTokens) as Map;
          expect(token, tokens[app.effectiveUserId]);
          return;
        }
        if (!hasInjectedSsoSecret) {
          expect(token, octopusUserToken);
          return;
        }

        final parts = token.split('.');
        expect(parts, hasLength(3));
        expect(parts.any((part) => part.contains('=')), isFalse);
        Object? decode(String part) => jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(part))),
        );
        expect(decode(parts[0]), {'alg': 'HS256', 'typ': 'JWT'});
        final payload = decode(parts[1]) as Map<String, dynamic>;
        expect(payload['sub'], app.effectiveUserId);
        expect(payload['entitlements'], entitlements);
        expect(payload['exp'], inInclusiveRange(earliestExpiry, latestExpiry));
        final expectedSignature = Hmac(
          sha256,
          utf8.encode(octopusSsoClientUserTokenSecret),
        ).convert(utf8.encode('${parts[0]}.${parts[1]}')).bytes;
        expect(
          base64Url.decode(base64Url.normalize(parts[2])),
          expectedSignature,
        );
      }

      await expectToken('initial-connect', ['premium']);
      app.setCurrentEntitlements({'premium', 'moderator'});
      await expectToken('refresh-entitlements', ['moderator', 'premium']);
    },
  );
}
