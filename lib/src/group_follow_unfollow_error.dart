import 'package:flutter/foundation.dart' show immutable;

import 'octopus_result.dart';

/// Typed errors returned by [OctopusSDK.followGroup] / [OctopusSDK.unfollowGroup]
/// inside an [OctopusInvalidArguments].
///
/// Mirrors the native `GroupFollowUnfollowError` (Android). A sealed class (not
/// an enum) so future server-side variants can be added without a breaking
/// change to the pattern-match.
///
/// Platform contract: connection- and auth-level failures (no network, user not
/// connected) are **not** modelled here — they surface through the orthogonal
/// [OctopusConnectionFailure] branch of the [OctopusResult] ([OctopusNoNetwork],
/// [OctopusUserNotAuthenticated], …). Only the business errors below flow
/// through [OctopusInvalidArguments].
///
/// **Platform note**: on Android the specific typed errors below are produced
/// natively. iOS does not expose individual `followGroup` / `unfollowGroup` —
/// the bridge maps onto the batch `syncFollowGroups` API and translates the
/// per-action status into these typed errors. iOS has no equivalent of
/// [GroupFollowUnfollowLastFollowedGroupError]; unfollowing the last followed
/// group succeeds silently on iOS.
@immutable
sealed class GroupFollowUnfollowError implements OctopusServerError {
  const GroupFollowUnfollowError();

  /// Decodes the platform-channel representation of a single error.
  ///
  /// Reads defensively: an unrecognized/missing `type` folds to
  /// [GroupFollowUnfollowUnknownError], and a missing/non-String `message`
  /// falls back to a placeholder.
  factory GroupFollowUnfollowError.fromWire(Map<String, dynamic> wire) {
    final message =
        wire['message'] is String ? wire['message'] as String : 'Unknown error';
    switch (wire['type']) {
      case 'missingGroup':
        return GroupFollowUnfollowMissingGroupError(message);
      case 'unfollowableGroup':
        return GroupFollowUnfollowUnfollowableGroupError(message);
      case 'groupAlreadyFollowed':
        return GroupFollowUnfollowGroupAlreadyFollowedError(message);
      case 'groupAlreadyUnfollowed':
        return GroupFollowUnfollowGroupAlreadyUnfollowedError(message);
      case 'lastFollowedGroup':
        return GroupFollowUnfollowLastFollowedGroupError(message);
      case 'unknown':
      default:
        return GroupFollowUnfollowUnknownError(message);
    }
  }
}

/// No group exists with the given id.
@immutable
final class GroupFollowUnfollowMissingGroupError
    extends GroupFollowUnfollowError {
  @override
  final String errorMessage;
  const GroupFollowUnfollowMissingGroupError(this.errorMessage);

  @override
  bool operator ==(Object other) =>
      other is GroupFollowUnfollowMissingGroupError &&
      other.errorMessage == errorMessage;
  @override
  int get hashCode => errorMessage.hashCode;
  @override
  String toString() => 'GroupFollowUnfollowMissingGroupError($errorMessage)';
}

/// The group is not followable / not unfollowable (e.g. admin-restricted, or an
/// essential/force-followed group that cannot be unfollowed).
@immutable
final class GroupFollowUnfollowUnfollowableGroupError
    extends GroupFollowUnfollowError {
  @override
  final String errorMessage;
  const GroupFollowUnfollowUnfollowableGroupError(this.errorMessage);

  @override
  bool operator ==(Object other) =>
      other is GroupFollowUnfollowUnfollowableGroupError &&
      other.errorMessage == errorMessage;
  @override
  int get hashCode => errorMessage.hashCode;
  @override
  String toString() =>
      'GroupFollowUnfollowUnfollowableGroupError($errorMessage)';
}

/// The connected user already follows the group — server state unchanged.
@immutable
final class GroupFollowUnfollowGroupAlreadyFollowedError
    extends GroupFollowUnfollowError {
  @override
  final String errorMessage;
  const GroupFollowUnfollowGroupAlreadyFollowedError(this.errorMessage);

  @override
  bool operator ==(Object other) =>
      other is GroupFollowUnfollowGroupAlreadyFollowedError &&
      other.errorMessage == errorMessage;
  @override
  int get hashCode => errorMessage.hashCode;
  @override
  String toString() =>
      'GroupFollowUnfollowGroupAlreadyFollowedError($errorMessage)';
}

/// The connected user already does not follow the group — server state
/// unchanged.
@immutable
final class GroupFollowUnfollowGroupAlreadyUnfollowedError
    extends GroupFollowUnfollowError {
  @override
  final String errorMessage;
  const GroupFollowUnfollowGroupAlreadyUnfollowedError(this.errorMessage);

  @override
  bool operator ==(Object other) =>
      other is GroupFollowUnfollowGroupAlreadyUnfollowedError &&
      other.errorMessage == errorMessage;
  @override
  int get hashCode => errorMessage.hashCode;
  @override
  String toString() =>
      'GroupFollowUnfollowGroupAlreadyUnfollowedError($errorMessage)';
}

/// Returned by [OctopusSDK.unfollowGroup] when the user attempts to unfollow
/// their last followed group. A user must always have at least one followed
/// group (counting both voluntarily-followed and force-followed groups). This
/// guard matches the behaviour of the built-in Octopus SDK UI.
///
/// **Platform note**: Android-only — iOS has no equivalent server status and
/// silently succeeds when this case arises.
@immutable
final class GroupFollowUnfollowLastFollowedGroupError
    extends GroupFollowUnfollowError {
  @override
  final String errorMessage;
  const GroupFollowUnfollowLastFollowedGroupError(this.errorMessage);

  @override
  bool operator ==(Object other) =>
      other is GroupFollowUnfollowLastFollowedGroupError &&
      other.errorMessage == errorMessage;
  @override
  int get hashCode => errorMessage.hashCode;
  @override
  String toString() =>
      'GroupFollowUnfollowLastFollowedGroupError($errorMessage)';
}

/// An unclassified backend error occurred.
@immutable
final class GroupFollowUnfollowUnknownError extends GroupFollowUnfollowError {
  @override
  final String errorMessage;
  const GroupFollowUnfollowUnknownError(this.errorMessage);

  @override
  bool operator ==(Object other) =>
      other is GroupFollowUnfollowUnknownError &&
      other.errorMessage == errorMessage;
  @override
  int get hashCode => errorMessage.hashCode;
  @override
  String toString() => 'GroupFollowUnfollowUnknownError($errorMessage)';
}
