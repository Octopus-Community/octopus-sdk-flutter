import 'package:flutter/foundation.dart' show immutable;

import 'octopus_result.dart';

/// Typed errors returned by [OctopusSDK.refreshEntitlements] inside an
/// [OctopusInvalidArguments].
///
/// Mirrors the native `RefreshEntitlementsError` (Android) /
/// `OctopusRefreshEntitlementsError` (iOS). A sealed class (not an enum) so
/// future server-side variants can be added without a breaking change to the
/// pattern-match.
@immutable
sealed class RefreshEntitlementsError implements OctopusServerError {
  const RefreshEntitlementsError();

  /// Decodes the platform-channel representation of a single error.
  ///
  /// Reads defensively: an unrecognized/missing `type` folds to
  /// [RefreshEntitlementsServerError], and a missing/non-String `message`
  /// falls back to a placeholder.
  factory RefreshEntitlementsError.fromWire(Map<String, dynamic> wire) {
    final message =
        wire['message'] is String ? wire['message'] as String : 'Unknown error';
    switch (wire['type']) {
      case 'noClientTokenProvider':
        return RefreshEntitlementsNoClientTokenProviderError(message);
      case 'userNotConnected':
        return RefreshEntitlementsUserNotConnectedError(message);
      case 'noNetwork':
        return RefreshEntitlementsNoNetworkError(message);
      case 'userBanned':
        return RefreshEntitlementsUserBannedError(message);
      case 'serverError':
      default:
        return RefreshEntitlementsServerError(message);
    }
  }
}

/// Entitlements refresh is only supported in SSO mode with a registered token
/// provider; the current connection has none.
@immutable
final class RefreshEntitlementsNoClientTokenProviderError
    extends RefreshEntitlementsError {
  @override
  final String errorMessage;
  const RefreshEntitlementsNoClientTokenProviderError(this.errorMessage);

  @override
  bool operator ==(Object other) =>
      other is RefreshEntitlementsNoClientTokenProviderError &&
      other.errorMessage == errorMessage;
  @override
  int get hashCode => errorMessage.hashCode;
  @override
  String toString() =>
      'RefreshEntitlementsNoClientTokenProviderError($errorMessage)';
}

/// No connected (non-guest) user; connect a user first.
@immutable
final class RefreshEntitlementsUserNotConnectedError
    extends RefreshEntitlementsError {
  @override
  final String errorMessage;
  const RefreshEntitlementsUserNotConnectedError(this.errorMessage);

  @override
  bool operator ==(Object other) =>
      other is RefreshEntitlementsUserNotConnectedError &&
      other.errorMessage == errorMessage;
  @override
  int get hashCode => errorMessage.hashCode;
  @override
  String toString() =>
      'RefreshEntitlementsUserNotConnectedError($errorMessage)';
}

/// No network connection was available.
@immutable
final class RefreshEntitlementsNoNetworkError extends RefreshEntitlementsError {
  @override
  final String errorMessage;
  const RefreshEntitlementsNoNetworkError(this.errorMessage);

  @override
  bool operator ==(Object other) =>
      other is RefreshEntitlementsNoNetworkError &&
      other.errorMessage == errorMessage;
  @override
  int get hashCode => errorMessage.hashCode;
  @override
  String toString() => 'RefreshEntitlementsNoNetworkError($errorMessage)';
}

/// The user has been banned. [errorMessage] is the backend-provided message and
/// is appropriate for direct display.
@immutable
final class RefreshEntitlementsUserBannedError
    extends RefreshEntitlementsError {
  @override
  final String errorMessage;
  const RefreshEntitlementsUserBannedError(this.errorMessage);

  @override
  bool operator ==(Object other) =>
      other is RefreshEntitlementsUserBannedError &&
      other.errorMessage == errorMessage;
  @override
  int get hashCode => errorMessage.hashCode;
  @override
  String toString() => 'RefreshEntitlementsUserBannedError($errorMessage)';
}

/// The backend returned a generic error.
@immutable
final class RefreshEntitlementsServerError extends RefreshEntitlementsError {
  @override
  final String errorMessage;
  const RefreshEntitlementsServerError(this.errorMessage);

  @override
  bool operator ==(Object other) =>
      other is RefreshEntitlementsServerError &&
      other.errorMessage == errorMessage;
  @override
  int get hashCode => errorMessage.hashCode;
  @override
  String toString() => 'RefreshEntitlementsServerError($errorMessage)';
}
