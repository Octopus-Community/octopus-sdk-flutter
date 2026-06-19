/// A single follow/unfollow action to sync for a group, with its own timestamp.
///
/// The backend compares [actionDate] to the stored timestamp for the
/// (user, group) pair and only applies more recent actions — stale actions
/// are silently returned as [SyncFollowGroupStatus.skipped].
class SyncFollowGroupAction {
  final String groupId;
  final bool followed;
  final DateTime actionDate;

  const SyncFollowGroupAction({
    required this.groupId,
    required this.followed,
    required this.actionDate,
  });
}

/// The per-action outcome returned by the backend.
class SyncFollowGroupResult {
  final String groupId;
  final SyncFollowGroupStatus status;

  const SyncFollowGroupResult({required this.groupId, required this.status});
}

/// The outcome status for a single action inside a sync batch.
///
/// Mirrors the native `OctopusSyncFollowGroup.Status` enum on iOS and
/// `SyncFollowGroupStatus` on Android. Unknown wire values from a future
/// native SDK round-trip to [unknownError] for forward compatibility.
enum SyncFollowGroupStatus {
  applied,
  skipped,
  groupNotFound,
  notFollowable,
  notUnfollowable,
  alreadyFollowed,
  alreadyUnfollowed,
  unknownError;

  /// Stable lowercase snake_case wire value used on the MethodChannel.
  String get wireValue {
    switch (this) {
      case SyncFollowGroupStatus.applied:
        return 'applied';
      case SyncFollowGroupStatus.skipped:
        return 'skipped';
      case SyncFollowGroupStatus.groupNotFound:
        return 'group_not_found';
      case SyncFollowGroupStatus.notFollowable:
        return 'not_followable';
      case SyncFollowGroupStatus.notUnfollowable:
        return 'not_unfollowable';
      case SyncFollowGroupStatus.alreadyFollowed:
        return 'already_followed';
      case SyncFollowGroupStatus.alreadyUnfollowed:
        return 'already_unfollowed';
      case SyncFollowGroupStatus.unknownError:
        return 'unknown_error';
    }
  }

  static SyncFollowGroupStatus fromWire(String value) {
    for (final s in SyncFollowGroupStatus.values) {
      if (s.wireValue == value) return s;
    }
    return SyncFollowGroupStatus.unknownError;
  }
}
