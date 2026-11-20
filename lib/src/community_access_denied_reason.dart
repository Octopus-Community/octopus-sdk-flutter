import 'octopus_sdk.dart';

/// Why the current user cannot access the community.
///
/// Read it from [OctopusSDK.communityAccessDeniedReason], next to
/// [OctopusSDK.hasAccessToCommunity]. When the access is denied, the SDK's
/// screens display a dedicated screen for this reason in place of the
/// community: your app has nothing to display.
///
/// Mirrors the native iOS `OctopusCommunityAccessDeniedReason` and Android
/// `CommunityAccessDeniedReason`.
enum CommunityAccessDeniedReason {
  /// The user is not part of the audience the community is opened to (for
  /// example, they are out of the A/B test cohort).
  notInCohort,

  /// The community is disabled for a while. It is expected to come back.
  communityTemporarilyDisabled,

  /// The community is closed.
  communityClosed,

  /// The member is excluded from the community.
  memberExcluded,

  /// The account of the member is banned. The details of the ban (the policy
  /// that was broken, who to contact) are displayed by the SDK and are not
  /// exposed.
  ///
  /// [OctopusSDK.connectUser] keeps reporting a banned member with a
  /// [ClientUserBannedError].
  accountBanned,

  /// The account of the member has been deleted. Your app can disconnect the
  /// member on its side, with [OctopusSDK.disconnectUser]. The SDK lets the
  /// member access the community again from its screen.
  accountDeleted,

  /// The server gives no reason, or gives one that this version of the SDK
  /// does not know.
  unknown;

  /// Decodes the wire value sent by the native bridges.
  ///
  /// The wire value mirrors the native enum names (`NOT_IN_COHORT`,
  /// `COMMUNITY_TEMPORARILY_DISABLED`, `COMMUNITY_CLOSED`, `MEMBER_EXCLUDED`,
  /// `ACCOUNT_BANNED`, `ACCOUNT_DELETED`, `UNKNOWN`). `null` (access granted
  /// or not known yet) decodes to `null`; any other value — one a newer native
  /// SDK added — decodes to [unknown].
  static CommunityAccessDeniedReason? fromNativeValue(Object? value) {
    if (value == null) return null;
    return switch (value) {
      'NOT_IN_COHORT' => notInCohort,
      'COMMUNITY_TEMPORARILY_DISABLED' => communityTemporarilyDisabled,
      'COMMUNITY_CLOSED' => communityClosed,
      'MEMBER_EXCLUDED' => memberExcluded,
      'ACCOUNT_BANNED' => accountBanned,
      'ACCOUNT_DELETED' => accountDeleted,
      _ => unknown,
    };
  }
}
