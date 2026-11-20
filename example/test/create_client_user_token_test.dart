import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/auth/client_user_token_signer.dart';
import 'package:octopus_sdk_flutter_example/config/user_id_registry.dart';

void main() {
  test(
    'compiled provider supports local signing, fallback, presigned and expired tokens',
    () async {
      // Compile-time constants require separate compilations. Generate only
      // synthetic inputs here; do not load any developer configuration.
      final random = Random.secure();
      String testValue() =>
          'test-only-${base64Url.encode(List.generate(32, (_) => random.nextInt(256)))}';
      final secret = testValue();
      final fallback = testValue();
      final flutterRoot = Platform.environment['FLUTTER_ROOT'];
      final flutterExecutable = flutterRoot == null || flutterRoot.isEmpty
          ? 'flutter'
          : '$flutterRoot/bin/flutter';
      for (final mode in ['signed', 'fallback', 'presigned', 'expired']) {
        // The store compilation has tokens but no secret. The expired case
        // also injects a local secret to prove expiry cannot bypass the map.
        final expectSsoSigning = mode == 'signed' || mode == 'expired';
        final presigned = mode == 'presigned' || mode == 'expired';
        final tokens = presigned
            ? jsonEncode({
                for (final userId in pickerUserIds)
                  userId: ClientUserTokenSigner.signWith(
                    secret: 'synthetic-ci-secret',
                    userId: userId,
                    entitlements: const {},
                    exp:
                        DateTime.utc(
                          mode == 'expired' ? 2000 : 2100,
                        ).millisecondsSinceEpoch ~/
                        1000,
                  ),
              })
            : '';
        final result = await Process.run(flutterExecutable, [
          'test',
          '--suppress-analytics',
          '--no-pub',
          '--reporter=expanded',
          '--dart-define=EXPECT_SSO_SIGNING=$expectSsoSigning',
          '--dart-define=EXPECT_DEMO_TOKEN_MODE=$mode',
          '--dart-define=OCTOPUS_DEMO_USER_TOKENS=$tokens',
          '--dart-define=OCTOPUS_SSO_CLIENT_USER_TOKEN_SECRET=${expectSsoSigning ? secret : ''}',
          '--dart-define=OCTOPUS_USER_TOKEN=$fallback',
          'test/fixtures/create_client_user_token.dart',
        ]);
        expect(
          result.exitCode,
          0,
          reason: '$mode compilation:\n${result.stdout}\n${result.stderr}',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
