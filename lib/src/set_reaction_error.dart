import 'package:flutter/foundation.dart' show immutable;

import 'octopus_result.dart';

/// Typed errors returned by [OctopusSDK.setReaction] inside an
/// [OctopusInvalidArguments].
///
/// Mirrors the native `SetReactionError` (Android) / `OctopusSetReactionError`
/// (iOS). A sealed class (not an enum) so future server-side variants can be
/// added without a breaking change to the pattern-match.
///
/// Note the platform contract: connection- and auth-level failures
/// (no network, user not connected) are **not** modelled here — they surface
/// through the orthogonal [OctopusConnectionFailure] branch of the
/// [OctopusResult] ([OctopusNoNetwork], [OctopusUserNotAuthenticated], …),
/// matching the native Android SDK. Only the three business errors below flow
/// through [OctopusInvalidArguments].
@immutable
sealed class SetReactionError implements OctopusServerError {
  const SetReactionError();

  /// Decodes the platform-channel representation of a single error.
  ///
  /// Reads defensively: an unrecognized/missing `type` folds to
  /// [SetReactionReactionError], and a missing/non-String `message` falls back
  /// to a placeholder.
  factory SetReactionError.fromWire(Map<String, dynamic> wire) {
    final message =
        wire['message'] is String ? wire['message'] as String : 'Unknown error';
    switch (wire['type']) {
      case 'unknownReaction':
        return const SetReactionUnknownReactionError();
      case 'postNotFound':
        return const SetReactionPostNotFoundError();
      case 'reactionError':
      default:
        return SetReactionReactionError(message);
    }
  }
}

/// An unknown reaction kind was passed (an [OctopusUnknownReaction]). Only the
/// known reaction kinds are supported by the backend.
@immutable
final class SetReactionUnknownReactionError extends SetReactionError {
  const SetReactionUnknownReactionError();

  @override
  String get errorMessage => 'Unknown reaction not permitted';

  @override
  bool operator ==(Object other) => other is SetReactionUnknownReactionError;

  @override
  int get hashCode => (SetReactionUnknownReactionError).hashCode;

  @override
  String toString() => 'SetReactionUnknownReactionError()';
}

/// The post with the given id was not found, or the current user has no read
/// access to it.
@immutable
final class SetReactionPostNotFoundError extends SetReactionError {
  const SetReactionPostNotFoundError();

  @override
  String get errorMessage => 'Post not found';

  @override
  bool operator ==(Object other) => other is SetReactionPostNotFoundError;

  @override
  int get hashCode => (SetReactionPostNotFoundError).hashCode;

  @override
  String toString() => 'SetReactionPostNotFoundError()';
}

/// An error occurred while setting the reaction on the server. On iOS this also
/// covers the native `serverError`/`other` cases.
@immutable
final class SetReactionReactionError extends SetReactionError {
  @override
  final String errorMessage;

  const SetReactionReactionError(this.errorMessage);

  @override
  bool operator ==(Object other) =>
      other is SetReactionReactionError && other.errorMessage == errorMessage;

  @override
  int get hashCode => errorMessage.hashCode;

  @override
  String toString() => 'SetReactionReactionError($errorMessage)';
}
