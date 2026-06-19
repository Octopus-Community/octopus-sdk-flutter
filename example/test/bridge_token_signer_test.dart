import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_sdk_flutter_example/auth/bridge_token_signer.dart';

void main() {
  group('BridgeTokenSigner', () {
    test('signBridgeFingerprint returns null when no SSO secret is injected', () {
      // The test binary has no `--dart-define=OCTOPUS_SSO_CLIENT_USER_TOKEN_SECRET`,
      // so `octopusSsoClientUserTokenSecret` is empty and the signer short-
      // circuits to null — matches the public-build behavior.
      final token = BridgeTokenSigner.signBridgeFingerprint('test-fingerprint');
      expect(token, isNull);
    });

    // Exercise the actual production code (`signWith`) with a fixed
    // (secret, fingerprint, exp) triple. Asserting the exact token bytes
    // means a future regression in header literal, payload encoding,
    // base64url no-pad rules, or HMAC computation will fail the test.
    test('signWith produces the expected JWT bytes (golden)', () {
      const secret = 'demo-test-secret';
      const fingerprint = 'abc123-fingerprint';
      const exp = 9999999999;

      final token = BridgeTokenSigner.signWith(
        secret: secret,
        bridgeFingerprint: fingerprint,
        exp: exp,
      );

      // Golden: recompute the same JWT inline so the test pins each
      // sub-component the production signer is supposed to emit. If any
      // of the rules drift, the equality below fails.
      final headerB64 = _b64UrlNoPad(
        utf8.encode('{"alg":"HS256","typ":"JWT"}'),
      );
      final payloadB64 = _b64UrlNoPad(
        utf8.encode(
          jsonEncode({'bridge_fingerprint': fingerprint, 'exp': exp}),
        ),
      );
      final sigB64 = _b64UrlNoPad(
        Hmac(
          sha256,
          utf8.encode(secret),
        ).convert(utf8.encode('$headerB64.$payloadB64')).bytes,
      );
      final expected = '$headerB64.$payloadB64.$sigB64';

      expect(token, expected);

      // Spot-check decoded sub-components — fails loudly if the signer
      // ever emits a different shape that happens to round-trip.
      final parts = token.split('.');
      expect(parts.length, 3);

      final header = jsonDecode(
        utf8.decode(base64Url.decode(_padBase64(parts[0]))),
      );
      expect(header, {'alg': 'HS256', 'typ': 'JWT'});

      final payload = jsonDecode(
        utf8.decode(base64Url.decode(_padBase64(parts[1]))),
      );
      expect(payload['bridge_fingerprint'], fingerprint);
      expect(payload['exp'], exp);
      expect(payload.length, 2);

      // No '+' / '/' / '=' in any segment (base64url, no padding).
      for (final part in parts) {
        expect(part.contains('+'), isFalse);
        expect(part.contains('/'), isFalse);
        expect(part.contains('='), isFalse);
      }
    });

    test('signWith varies the signature when the fingerprint changes', () {
      // Same secret + exp, different fingerprint → header & exp segments
      // identical but signature different (HMAC key + payload changed).
      const secret = 'demo-test-secret';
      const exp = 9999999999;
      final a = BridgeTokenSigner.signWith(
        secret: secret,
        bridgeFingerprint: 'fingerprint-a',
        exp: exp,
      );
      final b = BridgeTokenSigner.signWith(
        secret: secret,
        bridgeFingerprint: 'fingerprint-b',
        exp: exp,
      );
      expect(a.split('.').first, b.split('.').first); // same header
      expect(a, isNot(b));
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
