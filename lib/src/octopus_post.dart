import 'package:flutter/foundation.dart' show immutable, listEquals;

import 'octopus_reaction_kind.dart';

/// The number of reactions of a given [reactionKind] on a post.
///
/// Mirrors the native `OctopusReactionCount`. A reaction kind missing from
/// [OctopusPost.reactions] means its count is 0.
@immutable
class OctopusReactionCount {
  /// The reaction kind this count is for.
  final OctopusReactionKind reactionKind;

  /// The number of reactions of [reactionKind].
  final int count;

  /// Creates a reaction count.
  const OctopusReactionCount({required this.reactionKind, required this.count});

  /// Decodes the platform-channel representation. Reads defensively: an
  /// unknown/missing kind folds to [OctopusUnknownReaction] and a missing count
  /// to 0, so a version-skewed native side never throws into the host app.
  factory OctopusReactionCount.fromWire(Map<dynamic, dynamic> wire) {
    final rawKind = wire['reactionKind'];
    return OctopusReactionCount(
      reactionKind: OctopusReactionKind.fromWire(
        rawKind is Map ? Map<String, dynamic>.from(rawKind) : const {},
      ),
      count: wire['count'] is num ? (wire['count'] as num).toInt() : 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OctopusReactionCount &&
          other.reactionKind == reactionKind &&
          other.count == count;

  @override
  int get hashCode => Object.hash(reactionKind, count);

  @override
  String toString() =>
      'OctopusReactionCount(reactionKind: $reactionKind, count: $count)';
}

/// A read-only view of an Octopus post.
///
/// Returned by [OctopusSDK.fetchOrCreateClientObjectRelatedPost] and emitted by
/// [OctopusSDK.getClientObjectRelatedPostFlow]. Use [id] to display the post in
/// the embedded UI.
///
/// This is the **lean** intersection of the native read interfaces — both
/// Android (`OctopusPost`) and iOS (`OctopusPost`) expose exactly these five
/// members publicly. Field names follow Android (the reference SDK): iOS calls
/// [userReactionKind] `userReaction` and [OctopusReactionCount.reactionKind]
/// `reaction`.
@immutable
class OctopusPost {
  /// Id of the post. Pass it to the embedded UI to display the post.
  final String id;

  /// The reaction counts. A kind missing from this list has a count of 0.
  final List<OctopusReactionCount> reactions;

  /// The overall number of **comments and replies** on this post.
  final int commentCount;

  /// The number of times this post has been viewed.
  final int viewCount;

  /// The current user's reaction on this post, or `null` if they did not react.
  final OctopusReactionKind? userReactionKind;

  /// Creates an Octopus post view.
  const OctopusPost({
    required this.id,
    this.reactions = const <OctopusReactionCount>[],
    this.commentCount = 0,
    this.viewCount = 0,
    this.userReactionKind,
  });

  /// Decodes the platform-channel representation produced by both native
  /// bridges. Reads defensively so a version-skewed native side degrades
  /// gracefully (missing id → empty, missing counts → 0) instead of throwing.
  factory OctopusPost.fromWire(Map<dynamic, dynamic> wire) {
    final rawReactions = wire['reactions'];
    final rawUserReaction = wire['userReactionKind'];
    return OctopusPost(
      id: wire['id'] is String ? wire['id'] as String : '',
      reactions: <OctopusReactionCount>[
        if (rawReactions is List)
          for (final r in rawReactions.whereType<Map>())
            OctopusReactionCount.fromWire(r),
      ],
      commentCount: wire['commentCount'] is num
          ? (wire['commentCount'] as num).toInt()
          : 0,
      viewCount:
          wire['viewCount'] is num ? (wire['viewCount'] as num).toInt() : 0,
      userReactionKind: rawUserReaction is Map
          ? OctopusReactionKind.fromWire(
              Map<String, dynamic>.from(rawUserReaction))
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OctopusPost &&
          other.id == id &&
          listEquals(other.reactions, reactions) &&
          other.commentCount == commentCount &&
          other.viewCount == viewCount &&
          other.userReactionKind == userReactionKind;

  @override
  int get hashCode => Object.hash(
        id,
        Object.hashAll(reactions),
        commentCount,
        viewCount,
        userReactionKind,
      );

  @override
  String toString() => 'OctopusPost(id: $id, reactions: $reactions, '
      'commentCount: $commentCount, viewCount: $viewCount, '
      'userReactionKind: $userReactionKind)';
}
