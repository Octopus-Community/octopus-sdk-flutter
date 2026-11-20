import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/auth/client_user_token_signer.dart';
import 'package:octopus_sdk_flutter_example/auth/demo_user_token_provider.dart';

void main() {
  final now = DateTime.utc(2026, 10, 21);
  final seconds = now.millisecondsSinceEpoch ~/ 1000;
  String tokenFor(String userId, int exp) => ClientUserTokenSigner.signWith(
    secret: 'synthetic-test-secret',
    userId: userId,
    entitlements: const {},
    exp: exp,
  );
  String select(String tokens, {String userId = 'first'}) =>
      selectDemoUserToken(
        userId: userId,
        entitlements: const {'premium'},
        preSignedTokens: tokens,
        localSecret: 'synthetic-local-secret',
        fallbackToken: 'synthetic-fallback',
        now: now,
      );
  Matcher failure(String text) => throwsA(
    isA<DemoUserTokenException>().having(
      (e) => e.message,
      'message',
      contains(text),
    ),
  );

  test('selects the requested pre-signed user ahead of local signing', () {
    final first = tokenFor('first', seconds + 1);
    final second = tokenFor('second', seconds + 3600);
    final tokens = jsonEncode({'first': first, 'second': second});
    expect(select(tokens), first);
    expect(select(tokens, userId: 'second'), second);
  });

  test('expired tokens never fall back to signing or the legacy token', () {
    for (final exp in [seconds - 1, seconds]) {
      expect(
        () => select(jsonEncode({'first': tokenFor('first', exp)})),
        failure("This build's demo tokens expired"),
      );
    }
  });

  test('a custom user cannot reuse another user token or sign locally', () {
    expect(
      () => select(jsonEncode({'second': tokenFor('second', seconds + 1)})),
      failure('no demo token for the selected user'),
    );
  });

  test('malformed maps and claims fail without leaking their content', () {
    final wrongSubject = tokenFor('second', seconds + 1);
    final missingExpiry =
        'header.${base64Url.encode(utf8.encode('{"sub":"first"}'))}.signature';
    for (final value in [
      'not-json',
      '[]',
      '{"first":5}',
      '{"first":"not-a-jwt"}',
      '{"first":"header.%%%.signature"}',
      jsonEncode({'first': missingExpiry}),
      jsonEncode({'first': wrongSubject}),
    ]) {
      expect(() => select(value), failure('invalid demo tokens'));
    }
  });

  test(
    'local signing retains selected user, sorted entitlements and 1h expiry',
    () {
      final token = selectDemoUserToken(
        userId: 'custom-local-user',
        entitlements: const {'premium', 'moderator'},
        localSecret: 'synthetic-local-secret',
        preSignedTokens: '',
        fallbackToken: 'unused',
        now: now,
      );
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
      );
      expect(payload, {
        'sub': 'custom-local-user',
        'exp': seconds + 3600,
        'entitlements': ['moderator', 'premium'],
      });
    },
  );

  test(
    'legacy injected token and keyless local builds keep their fallback',
    () {
      for (final fallback in ['', 'synthetic-backend-token']) {
        expect(
          selectDemoUserToken(
            userId: 'first',
            entitlements: const {},
            preSignedTokens: '',
            localSecret: '',
            fallbackToken: fallback,
          ),
          fallback,
        );
      }
    },
  );
}
