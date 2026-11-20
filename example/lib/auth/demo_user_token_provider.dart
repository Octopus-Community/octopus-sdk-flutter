import 'dart:convert';

import '../octopus_demo_config.dart';
import 'client_user_token_signer.dart';

/// A safe, credential-free message for the sample's existing connection errors.
class DemoUserTokenException implements Exception {
  const DemoUserTokenException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Selects a build-signed token before considering local development signing.
///
/// Pre-signed builds cannot mint tokens for custom identities or change claims.
/// Decoding checks identity and expiry only; the backend verifies the signature.
String selectDemoUserToken({
  required String userId,
  required Set<String> entitlements,
  String preSignedTokens = octopusDemoUserTokens,
  String localSecret = octopusSsoClientUserTokenSecret,
  String fallbackToken = octopusUserToken,
  DateTime? now,
}) {
  final seconds = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
  if (preSignedTokens.isNotEmpty) {
    const invalid = DemoUserTokenException(
      'This build has invalid demo tokens. Install a newer build.',
    );
    try {
      final tokens = jsonDecode(preSignedTokens);
      if (tokens is! Map<String, dynamic>) throw invalid;
      final token = tokens[userId];
      if (token == null) {
        throw const DemoUserTokenException(
          'This build has no demo token for the selected user. Choose a bundled demo user.',
        );
      }
      if (token is! String) throw invalid;
      final parts = token.split('.');
      if (parts.length != 3 || parts.any((part) => part.isEmpty)) throw invalid;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map<String, dynamic> ||
          payload['sub'] != userId ||
          payload['exp'] is! int) {
        throw invalid;
      }
      if ((payload['exp'] as int) <= seconds) {
        throw const DemoUserTokenException(
          "This build's demo tokens expired. Install a newer build.",
        );
      }
      return token;
    } on FormatException {
      throw invalid;
    }
  }
  if (localSecret.isNotEmpty) {
    return ClientUserTokenSigner.signWith(
      secret: localSecret,
      userId: userId,
      entitlements: entitlements,
      exp: seconds + 3600,
    );
  }
  return fallbackToken;
}
