import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../octopus_demo_config.dart';

/// Host-side bridge-post signer for the Bridge → Client Object scenario.
///
/// `OctopusSDK.fetchOrCreateClientObjectRelatedPost` invokes a host-supplied
/// `tokenProvider(fingerprint)` whenever the SDK needs to **create** a new
/// bridge post (existing-post fetches don't need a signature). The token is
/// an HS256 JWT whose payload binds the SDK-provided `bridge_fingerprint` to
/// an expiry — the backend verifies the signature against the community's
/// shared SSO secret and accepts the create call.
///
/// **Demo-only**: this signer reads the secret from a `--dart-define`,
/// matching iOS's `TokenProvider.swift` which reads it from
/// `Bundle.main.infoDictionary["CLIENT_USER_TOKEN_SECRET"]`. A production
/// host should call a trusted backend route that returns the signature; the
/// secret never belongs in the client binary.
///
/// Returns `null` when [octopusSsoClientUserTokenSecret] is empty (keyless /
/// public build) — the SDK then surfaces an `invalidClientToken` error from
/// the backend, which the scenario reports in its result panel.
class BridgeTokenSigner {
  /// Signs [bridgeFingerprint] as an HS256 JWT and returns the encoded token,
  /// or `null` when no SSO secret was injected at build time.
  ///
  /// Token expiry is 1 h from now (matching iOS line 80 in
  /// `TokenProvider.swift`). Header / payload / signature are URL-safe-base64
  /// encoded without padding, per RFC 7515.
  static String? signBridgeFingerprint(String bridgeFingerprint) {
    if (!hasInjectedSsoSecret) return null;
    final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    return signWith(
      secret: octopusSsoClientUserTokenSecret,
      bridgeFingerprint: bridgeFingerprint,
      exp: exp,
    );
  }

  /// Deterministic core: produce the HS256 JWT for a given (secret,
  /// fingerprint, expiry) triple. Exposed so unit tests can exercise the
  /// **actual** production code path — `signBridgeFingerprint` resolves the
  /// secret + expiry against the runtime environment and delegates here.
  ///
  /// iOS parity:
  /// - Header literal `{"alg":"HS256","typ":"JWT"}` (TokenProvider.swift uses
  ///   `Header` Codable with `alg` then `typ` declared in that order).
  /// - Payload `{"bridge_fingerprint": ..., "exp": ...}` — snake_case key
  ///   matches iOS's `JSONEncoder.keyEncodingStrategy = .convertToSnakeCase`
  ///   (`BridgePostPayload.bridgeFingerprint` → `bridge_fingerprint`).
  /// - URL-safe base64 without padding (RFC 7515 §2).
  /// - HMAC-SHA256 over `header.payload` keyed by the UTF-8 bytes of the
  ///   secret.
  @visibleForTesting
  static String signWith({
    required String secret,
    required String bridgeFingerprint,
    required int exp,
  }) {
    final headerJson = '{"alg":"HS256","typ":"JWT"}';
    final payloadJson = jsonEncode({
      'bridge_fingerprint': bridgeFingerprint,
      'exp': exp,
    });

    final headerB64 = _b64UrlNoPad(utf8.encode(headerJson));
    final payloadB64 = _b64UrlNoPad(utf8.encode(payloadJson));
    final toSign = utf8.encode('$headerB64.$payloadB64');

    final hmac = Hmac(sha256, utf8.encode(secret));
    final signatureB64 = _b64UrlNoPad(hmac.convert(toSign).bytes);

    return '$headerB64.$payloadB64.$signatureB64';
  }

  /// Standard base64url encoding without padding (RFC 7515 §2). Dart's
  /// `base64Url.encode` emits padding; trim it to match the JWT spec.
  static String _b64UrlNoPad(List<int> bytes) {
    final s = base64Url.encode(bytes);
    final pad = s.indexOf('=');
    return pad == -1 ? s : s.substring(0, pad);
  }
}
