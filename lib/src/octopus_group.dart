import 'package:flutter/foundation.dart' show immutable;

/// A group (content category) in the Octopus community.
///
/// Exposed via [OctopusSDK.groups]. Mirrors the native `OctopusGroup`'s
/// public surface (Android + iOS). This is the **lean** consumer model — only
/// the fields exposed on both native platforms are surfaced; richer
/// Android-only fields (description, custom action, status, …) are intentionally
/// omitted until they are available on every platform. Future fields are
/// **additive only**.
@immutable
class OctopusGroup {
  /// Stable group identifier.
  final String id;

  /// Display name of the group.
  final String name;

  /// Whether the connected user currently follows this group.
  final bool isFollowed;

  /// Whether the connected user can change their follow status. `false` for
  /// essential/force-followed (or force-not-followed) groups controlled by
  /// community admins.
  final bool canChangeFollowStatus;

  /// Whether the connected user has access to this group. `true` for groups
  /// without an access requirement, or when the user holds the required
  /// entitlement. When `false`, the group is visible but locked (typically a
  /// premium/gated group) — taps should route through your
  /// `setGroupAccessDeniedCallback` handler instead of opening it.
  final bool canAccess;

  /// Whether the connected user is allowed to create posts in this group.
  /// `false` when the group is admin-only or otherwise gates post creation.
  final bool canCreateChildren;

  const OctopusGroup({
    required this.id,
    required this.name,
    this.isFollowed = false,
    this.canChangeFollowStatus = true,
    this.canAccess = true,
    this.canCreateChildren = true,
  });

  /// Decodes the platform-channel representation of a single group. Reads
  /// defensively: a missing/non-String `id` or `name` falls back to an empty
  /// string, and missing booleans use the same defaults as the native model.
  factory OctopusGroup.fromWire(Map<dynamic, dynamic> wire) {
    return OctopusGroup(
      id: wire['id'] is String ? wire['id'] as String : '',
      name: wire['name'] is String ? wire['name'] as String : '',
      isFollowed:
          wire['isFollowed'] is bool ? wire['isFollowed'] as bool : false,
      canChangeFollowStatus: wire['canChangeFollowStatus'] is bool
          ? wire['canChangeFollowStatus'] as bool
          : true,
      canAccess: wire['canAccess'] is bool ? wire['canAccess'] as bool : true,
      canCreateChildren: wire['canCreateChildren'] is bool
          ? wire['canCreateChildren'] as bool
          : true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OctopusGroup &&
      other.id == id &&
      other.name == name &&
      other.isFollowed == isFollowed &&
      other.canChangeFollowStatus == canChangeFollowStatus &&
      other.canAccess == canAccess &&
      other.canCreateChildren == canCreateChildren;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        isFollowed,
        canChangeFollowStatus,
        canAccess,
        canCreateChildren,
      );

  @override
  String toString() => 'OctopusGroup(id: $id, name: $name, '
      'isFollowed: $isFollowed, canChangeFollowStatus: $canChangeFollowStatus, '
      'canAccess: $canAccess, canCreateChildren: $canCreateChildren)';
}
