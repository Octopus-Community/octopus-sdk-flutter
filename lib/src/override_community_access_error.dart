import 'package:flutter/foundation.dart' show immutable;

import 'octopus_result.dart';

/// Typed errors returned by [OctopusSDK.overrideCommunityAccess] inside an
/// [OctopusInvalidArguments].
///
/// Mirrors the native `OverrideCommunityAccessError`. A sealed class (not an
/// enum) so future server-side variants can be added without a breaking change
/// to the pattern-match.
@immutable
sealed class OverrideCommunityAccessError implements OctopusServerError {
  const OverrideCommunityAccessError();

  /// Decodes the platform-channel representation of a single error.
  ///
  /// Reads defensively: any unrecognized `type` (including a future native
  /// variant) folds to [OverrideCommunityAccessUnknownError], and a
  /// missing/non-String `message` falls back to a placeholder rather than
  /// throwing.
  factory OverrideCommunityAccessError.fromWire(Map<String, dynamic> wire) {
    final message =
        wire['message'] is String ? wire['message'] as String : 'Unknown error';
    switch (wire['type']) {
      case 'unknown':
      default:
        return OverrideCommunityAccessUnknownError(message);
    }
  }
}

/// An unspecified error while overriding community access.
@immutable
final class OverrideCommunityAccessUnknownError
    extends OverrideCommunityAccessError {
  @override
  final String errorMessage;

  const OverrideCommunityAccessUnknownError(this.errorMessage);

  @override
  bool operator ==(Object other) =>
      other is OverrideCommunityAccessUnknownError &&
      other.errorMessage == errorMessage;

  @override
  int get hashCode => errorMessage.hashCode;

  @override
  String toString() => 'OverrideCommunityAccessUnknownError($errorMessage)';
}
