import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../octopus_demo_config.dart';

/// Host-side client-user-token signer.
///
/// `OctopusSDK.connectUser(tokenProvider:)` calls a host-supplied closure
/// (registered persistently for the connection's lifetime) every time the
/// native SDK needs a fresh user JWT — initial connect, and every refresh
/// (e.g. when `refreshEntitlements()` mints a new JWT with the host's
/// updated entitlement set).
///
/// **Demo-only**: this signer reads the secret from a `--dart-define`,
/// matching iOS's `TokenProvider.swift` which reads it from
/// `Bundle.main.infoDictionary["CLIENT_USER_TOKEN_SECRET"]`. A production
/// host should call a trusted backend route that mints the user JWT and
/// returns it — the secret never belongs in the client binary.
///
/// Returns an empty string when [octopusSsoClientUserTokenSecret] is empty
/// (keyless / public build). The SSO user is then not connected, but that is
/// not reported identically on both platforms: Android refuses an empty token
/// locally and reports `ClientUserMissingTokenError`, whereas iOS forwards it
/// to the backend token exchange, so what comes back depends on that call — a
/// connection-level failure rather than a typed `ClientUserError`, or no
/// failure at all when nothing was connected yet, since the native SDK then
/// falls back to a guest connection and `connectUser` returns
/// `OctopusSuccess`. See MIGRATING.md for that fallback.
class ClientUserTokenSigner {
  /// Signs a user JWT carrying [userId] + [entitlements], or returns an empty
  /// string if no SSO secret was injected at build time.
  ///
  /// Token expiry is 1 h from now (matching iOS `TokenProvider.swift`
  /// `getClientUserToken`).
  static String signClientUserToken({
    required String userId,
    required Set<String> entitlements,
  }) {
    if (!hasInjectedSsoSecret) return '';
    final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    return signWith(
      secret: octopusSsoClientUserTokenSecret,
      userId: userId,
      entitlements: entitlements,
      exp: exp,
    );
  }

  /// Deterministic core: produce the HS256 JWT for a given (secret, userId,
  /// entitlements, exp). Exposed so unit tests exercise the **actual**
  /// production code path.
  ///
  /// iOS parity (`TokenProvider.swift` `getClientUserToken`):
  /// - Header literal `{"alg":"HS256","typ":"JWT"}`.
  /// - Payload `{"sub": userId, "exp": exp, "entitlements": [...]}` —
  ///   `entitlements` is iOS-spelled the same way (no snake_case
  ///   `convertToSnakeCase` is set on this encoder, so `sub`/`exp`/
  ///   `entitlements` go through verbatim — same as Dart).
  /// - URL-safe base64 without padding (RFC 7515 §2).
  /// - HMAC-SHA256 over `header.payload` keyed by the UTF-8 bytes of the
  ///   secret.
  /// - Entitlements list is sorted (alphabetical) so two semantically equal
  ///   sets produce the same JWT bytes — mirrors iOS's
  ///   `currentEntitlements.map(\.rawValue).sorted()` in `AppUserManager`.
  @visibleForTesting
  static String signWith({
    required String secret,
    required String userId,
    required Set<String> entitlements,
    required int exp,
  }) {
    final headerJson = '{"alg":"HS256","typ":"JWT"}';
    final sortedEntitlements = entitlements.toList()..sort();
    final payloadJson = jsonEncode({
      'sub': userId,
      'exp': exp,
      'entitlements': sortedEntitlements,
    });

    final headerB64 = _b64UrlNoPad(utf8.encode(headerJson));
    final payloadB64 = _b64UrlNoPad(utf8.encode(payloadJson));
    final toSign = utf8.encode('$headerB64.$payloadB64');

    final hmac = Hmac(sha256, utf8.encode(secret));
    final signatureB64 = _b64UrlNoPad(hmac.convert(toSign).bytes);

    return '$headerB64.$payloadB64.$signatureB64';
  }

  static String _b64UrlNoPad(List<int> bytes) {
    final s = base64Url.encode(bytes);
    final pad = s.indexOf('=');
    return pad == -1 ? s : s.substring(0, pad);
  }
}
