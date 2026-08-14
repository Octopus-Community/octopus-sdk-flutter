import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

/// Renders a refused `connectUser` into a message the demo can display, and
/// `null` when the connection succeeded.
///
/// `connectUser` reports a refusal instead of throwing, so a host app that
/// only wraps the call in `try`/`catch` shows nothing at all when the backend
/// says no — the exact defect this helper exists to make visible in the demo.
///
/// The typed leaves are pattern-matched exhaustively so the automated UI tests
/// see which branch fired. Note the deliberate asymmetry: some leaves only
/// ever come from Android, others only from iOS (see the per-platform table on
/// [ClientUserError]), which is why every leaf is listed here rather than
/// assumed shared.
String? describeConnectUserFailure(
  OctopusResult<void, ClientUserError> result,
) {
  switch (result) {
    case OctopusSuccess():
      return null;
    case OctopusInvalidArguments<OctopusServerError>(:final errors):
      // Narrow back to the method's typed error to enumerate known leaves.
      final labels = errors
          .cast<ClientUserError>()
          .map((error) {
            final label = switch (error) {
              ClientUserMissingTokenError() => 'MissingToken',
              ClientUserBannedError() => 'Banned',
              ClientUserProfileError() => 'Profile',
              ClientUserInvalidTokenError() => 'InvalidToken',
              ClientUserCommunityAccessDeniedError() => 'CommunityAccessDenied',
              ClientUserOtherError() => 'Other',
            };
            return 'ClientUser$label: ${error.errorMessage}';
          })
          .join(', ');
      return 'connectUser refused: $labels';
    case OctopusConnectionFailure():
      // Connection-level failures (no typed error).
      return 'connectUser failed at the connection layer: $result';
  }
}
