import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'real token provider signs with an injected test secret and falls back without it',
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
      for (final mode in ['signed', 'fallback']) {
        final expectSsoSigning = mode == 'signed';
        final result = await Process.run(flutterExecutable, [
          'test',
          '--suppress-analytics',
          '--no-pub',
          '--reporter=expanded',
          '--dart-define=EXPECT_SSO_SIGNING=$expectSsoSigning',
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
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
