import 'package:flutter/foundation.dart' show immutable;

import 'octopus_result.dart';

/// Typed errors returned by [OctopusSDK.connectUser] inside an
/// [OctopusInvalidArguments].
///
/// Mirrors the native `ClientUserError` (Android) / `OctopusConnectUserError`
/// (iOS). A sealed class (not an enum) so future **server-side** variants can
/// be added without a breaking change to the pattern-match: a wire `type` this
/// version does not know folds into [ClientUserOtherError] rather than
/// appearing as a new leaf.
///
/// **The variants are not symmetric across platforms.** Each one below
/// documents which platform emits it at the currently pinned native SDK
/// versions, so do not narrow your handling to a single platform's subset: a
/// variant absent from a platform today may appear there tomorrow.
///
/// Switch over them **exhaustively, with no `default`/wildcard arm**. The
/// hierarchy is sealed, so the analyzer proves the switch complete and rejects
/// a catch-all — `unreachable_switch_default` for a `default:` arm,
/// `unreachable_switch_case` for a `case _:` or `_ =>` wildcard. Both are
/// warnings, and `flutter analyze` fails on warnings.
///
/// This holds once you have narrowed to [ClientUserError]. The result binds its
/// errors as `List<OctopusServerError>`, which is **not** sealed, so switch over
/// `errors.cast<ClientUserError>()` (or `whereType`) — a switch over the
/// unnarrowed list does need a catch-all.
///
/// You do not need one for robustness either: an unknown wire `type` folds into
/// [ClientUserOtherError], as above, so the set cannot grow under a running
/// host. A new leaf only ever arrives by upgrading this package, as a
/// source-breaking change called out in `CHANGELOG.md` and `MIGRATING.md`.
/// Read the CHANGELOG when you move the constraint: this package's minor tracks
/// the native SDKs it wraps, so a source-breaking change can land in a **minor**
/// bump.
///
/// | Variant | Android | iOS |
/// |---|---|---|
/// | [ClientUserMissingTokenError] | yes | no |
/// | [ClientUserBannedError] | yes | yes |
/// | [ClientUserProfileError] | yes | yes |
/// | [ClientUserInvalidTokenError] | no | yes |
/// | [ClientUserCommunityAccessDeniedError] | no | yes |
/// | [ClientUserOtherError] | yes | yes |
///
/// Failures that are not user-specific (no network, server status errors) do
/// not appear here: they surface as the connection-level [OctopusFailure]
/// variants ([OctopusNoNetwork], [OctopusStatusError]) like everywhere else in
/// the SDK.
@immutable
sealed class ClientUserError implements OctopusServerError {
  const ClientUserError();

  /// Decodes the platform-channel representation of a single error.
  ///
  /// Reads defensively: an unrecognized/missing `type` folds to
  /// [ClientUserOtherError], and a missing/non-String `message` falls back to
  /// a placeholder.
  factory ClientUserError.fromWire(Map<String, dynamic> wire) {
    final message =
        wire['message'] is String ? wire['message'] as String : 'Unknown error';
    switch (wire['type']) {
      case 'missingToken':
        return ClientUserMissingTokenError(message);
      case 'userBanned':
        return ClientUserBannedError(message);
      case 'profileError':
        return ClientUserProfileError(message);
      case 'invalidToken':
        return ClientUserInvalidTokenError(message);
      case 'communityAccessDenied':
        return ClientUserCommunityAccessDeniedError(message);
      case 'other':
      default:
        return ClientUserOtherError(message);
    }
  }
}

/// No token was available for the connection: the `tokenProvider` returned an
/// empty string, threw, or did not answer in time.
///
/// Emitted on **Android** only.
@immutable
final class ClientUserMissingTokenError extends ClientUserError {
  @override
  final String errorMessage;
  const ClientUserMissingTokenError(this.errorMessage);

  @override
  bool operator ==(Object other) =>
      other is ClientUserMissingTokenError &&
      other.errorMessage == errorMessage;
  @override
  int get hashCode => errorMessage.hashCode;
  @override
  String toString() => 'ClientUserMissingTokenError($errorMessage)';
}

/// The user is banned from the community.
///
/// [errorMessage] carries the backend's own wording and is meant to be
/// displayed to the user.
///
/// Emitted on **Android and iOS**.
@immutable
final class ClientUserBannedError extends ClientUserError {
  @override
  final String errorMessage;
  const ClientUserBannedError(this.errorMessage);

  @override
  bool operator ==(Object other) =>
      other is ClientUserBannedError && other.errorMessage == errorMessage;
  @override
  int get hashCode => errorMessage.hashCode;
  @override
  String toString() => 'ClientUserBannedError($errorMessage)';
}

/// The profile carried by the connection was rejected (nickname, bio or
/// picture failed validation).
///
/// Emitted on **Android and iOS**.
@immutable
final class ClientUserProfileError extends ClientUserError {
  @override
  final String errorMessage;
  const ClientUserProfileError(this.errorMessage);

  @override
  bool operator ==(Object other) =>
      other is ClientUserProfileError && other.errorMessage == errorMessage;
  @override
  int get hashCode => errorMessage.hashCode;
  @override
  String toString() => 'ClientUserProfileError($errorMessage)';
}

/// The JWT was refused: malformed, expired, or signed with the wrong key.
///
/// Emitted on **iOS** only.
@immutable
final class ClientUserInvalidTokenError extends ClientUserError {
  @override
  final String errorMessage;
  const ClientUserInvalidTokenError(this.errorMessage);

  @override
  bool operator ==(Object other) =>
      other is ClientUserInvalidTokenError &&
      other.errorMessage == errorMessage;
  @override
  int get hashCode => errorMessage.hashCode;
  @override
  String toString() => 'ClientUserInvalidTokenError($errorMessage)';
}

/// The backend refused this user access to the community.
///
/// Emitted on **iOS** only.
@immutable
final class ClientUserCommunityAccessDeniedError extends ClientUserError {
  @override
  final String errorMessage;
  const ClientUserCommunityAccessDeniedError(this.errorMessage);

  @override
  bool operator ==(Object other) =>
      other is ClientUserCommunityAccessDeniedError &&
      other.errorMessage == errorMessage;
  @override
  int get hashCode => errorMessage.hashCode;
  @override
  String toString() => 'ClientUserCommunityAccessDeniedError($errorMessage)';
}

/// Any other connection refusal reported by the native SDK.
///
/// Emitted on **Android and iOS**.
@immutable
final class ClientUserOtherError extends ClientUserError {
  @override
  final String errorMessage;
  const ClientUserOtherError(this.errorMessage);

  @override
  bool operator ==(Object other) =>
      other is ClientUserOtherError && other.errorMessage == errorMessage;
  @override
  int get hashCode => errorMessage.hashCode;
  @override
  String toString() => 'ClientUserOtherError($errorMessage)';
}
