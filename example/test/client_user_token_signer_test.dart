import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/auth/client_user_token_signer.dart';

void main() {
  group('ClientUserTokenSigner', () {
    test(
      'signClientUserToken returns empty string when no SSO secret injected',
      () {
        final token = ClientUserTokenSigner.signClientUserToken(
          userId: 'test-user',
          entitlements: const {'customer:premium'},
        );
        // String.fromEnvironment defaults to empty in test runners → signer
        // short-circuits → mirrors the keyless-build behavior the native SDK
        // treats as a tokenProvider failure.
        expect(token, isEmpty);
      },
    );

    test('signWith produces the expected JWT bytes (golden)', () {
      const secret = 'demo-test-secret';
      const userId = 'flutter-sample-user';
      const exp = 9999999999;
      const entitlements = {'customer:premium', 'customer:moderator'};

      final token = ClientUserTokenSigner.signWith(
        secret: secret,
        userId: userId,
        entitlements: entitlements,
        exp: exp,
      );

      // Golden: recompute the same JWT inline so the test pins every
      // sub-component the production signer is supposed to emit. Any drift
      // in header literal, payload encoding, sort order, base64url rules,
      // or HMAC computation will fail the equality below.
      final headerB64 = _b64UrlNoPad(
        utf8.encode('{"alg":"HS256","typ":"JWT"}'),
      );
      final sortedEntitlements = entitlements.toList()..sort();
      final payloadB64 = _b64UrlNoPad(
        utf8.encode(
          jsonEncode({
            'sub': userId,
            'exp': exp,
            'entitlements': sortedEntitlements,
          }),
        ),
      );
      final sigB64 = _b64UrlNoPad(
        Hmac(
          sha256,
          utf8.encode(secret),
        ).convert(utf8.encode('$headerB64.$payloadB64')).bytes,
      );
      expect(token, '$headerB64.$payloadB64.$sigB64');

      // Decoded sub-components — fails loudly if shape ever drifts.
      final parts = token.split('.');
      expect(parts.length, 3);

      final header = jsonDecode(
        utf8.decode(base64Url.decode(_padBase64(parts[0]))),
      );
      expect(header, {'alg': 'HS256', 'typ': 'JWT'});

      final payload = jsonDecode(
        utf8.decode(base64Url.decode(_padBase64(parts[1]))),
      );
      expect(payload['sub'], userId);
      expect(payload['exp'], exp);
      expect(payload['entitlements'], sortedEntitlements);
      expect(payload.length, 3);
    });

    test('signWith sorts the entitlements list (set → deterministic JWT)', () {
      // Two semantically equal sets in DIFFERENT iteration orders must
      // produce the SAME token — the iOS sample's AppUserManager sorts
      // entitlements before signing for exactly this property.
      const secret = 'demo-test-secret';
      const userId = 'flutter-sample-user';
      const exp = 9999999999;

      final a = ClientUserTokenSigner.signWith(
        secret: secret,
        userId: userId,
        entitlements: const {'customer:moderator', 'customer:premium'},
        exp: exp,
      );
      final b = ClientUserTokenSigner.signWith(
        secret: secret,
        userId: userId,
        entitlements: const {'customer:premium', 'customer:moderator'},
        exp: exp,
      );
      expect(a, b);
    });

    test('signWith with empty entitlements produces an empty list claim', () {
      const secret = 'demo-test-secret';
      const userId = 'flutter-sample-user';
      const exp = 9999999999;
      final token = ClientUserTokenSigner.signWith(
        secret: secret,
        userId: userId,
        entitlements: const {},
        exp: exp,
      );
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(_padBase64(token.split('.')[1]))),
      );
      expect(payload['entitlements'], <String>[]);
    });
  });
}

String _b64UrlNoPad(List<int> bytes) {
  final s = base64Url.encode(bytes);
  final pad = s.indexOf('=');
  return pad == -1 ? s : s.substring(0, pad);
}

String _padBase64(String b64) {
  final pad = (4 - b64.length % 4) % 4;
  return b64 + ('=' * pad);
}
