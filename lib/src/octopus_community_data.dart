import 'package:flutter/foundation.dart' show immutable;

/// A read-only snapshot of a member's public Octopus community activity.
///
/// This is the "Unified Profile" data surface: it lets your app enrich **its
/// own** profile screen with the member's Octopus stats, instead of sending the
/// user to the SDK's native profile screen. Fetch it with
/// [OctopusSDK.fetchCommunityData], or observe it with
/// [OctopusSDK.communityDataFlow].
///
/// Every field beyond [profileId] is nullable: the backend only exposes what the
/// community is configured to publish, so a community without gamification
/// reports `null` for [gamification], and a community that does not publish
/// message counts reports `null` for [messageCount]. Treat a `null` as "not
/// available", not as zero.
///
/// Mirrors the native `OctopusCommunityData` (Android + iOS). Future fields will
/// be added here — **additive only; no breaking changes**.
@immutable
class OctopusCommunityData {
  /// The member's Octopus profile id.
  ///
  /// Named `userId` on the native Android SDK and `profileId` on iOS; this
  /// wrapper uses `profileId` throughout, matching the id already reported by
  /// [OtherUserProfileScreen] and [OtherUserPostsScreen].
  final String profileId;

  /// How many posts, comments and replies the member has published, or `null`
  /// when the community does not publish that count.
  final int? messageCount;

  /// The member's gamification standing, or `null` when the community has no
  /// gamification configured.
  final OctopusGamification? gamification;

  const OctopusCommunityData({
    required this.profileId,
    this.messageCount,
    this.gamification,
  });

  /// Decodes the platform-channel representation. Reads defensively: a
  /// missing/malformed field yields `null` rather than throwing into the host
  /// app.
  factory OctopusCommunityData.fromWire(Map<dynamic, dynamic> wire) {
    final rawGamification = wire['gamification'];
    return OctopusCommunityData(
      profileId: wire['profileId'] is String ? wire['profileId'] as String : '',
      messageCount:
          wire['messageCount'] is int ? wire['messageCount'] as int : null,
      gamification: rawGamification is Map
          ? OctopusGamification.fromWire(rawGamification)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OctopusCommunityData &&
      other.profileId == profileId &&
      other.messageCount == messageCount &&
      other.gamification == gamification;

  @override
  int get hashCode => Object.hash(profileId, messageCount, gamification);

  @override
  String toString() => 'OctopusCommunityData(profileId: $profileId, '
      'messageCount: $messageCount, gamification: $gamification)';
}

/// A member's gamification standing inside the community.
///
/// Reached through [OctopusCommunityData.gamification]. Mirrors the native
/// `OctopusGamification` (Android + iOS).
@immutable
class OctopusGamification {
  /// The member's level index, as configured for the community.
  final int level;

  /// The member's raw points score.
  ///
  /// **Always `null` through this API**, your own profile included: both native
  /// SDKs resolve community data from a member's *public* profile, which never
  /// carries the score (it is available to back-office consumers only). The
  /// field exists for forward-compatibility, matching the native SDKs — do not
  /// build a UI that depends on it. Use [level] to show a member's standing.
  final int? score;

  const OctopusGamification({required this.level, this.score});

  /// Decodes the platform-channel representation. A missing/malformed `level`
  /// falls back to `0` rather than throwing into the host app.
  factory OctopusGamification.fromWire(Map<dynamic, dynamic> wire) =>
      OctopusGamification(
        level: wire['level'] is int ? wire['level'] as int : 0,
        score: wire['score'] is int ? wire['score'] as int : null,
      );

  @override
  bool operator ==(Object other) =>
      other is OctopusGamification &&
      other.level == level &&
      other.score == score;

  @override
  int get hashCode => Object.hash(level, score);

  @override
  String toString() => 'OctopusGamification(level: $level, score: $score)';
}
