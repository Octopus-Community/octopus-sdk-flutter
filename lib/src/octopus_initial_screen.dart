import 'package:flutter/foundation.dart' show immutable;

import 'create_post_screen_info.dart';

/// The initial screen to display when the embedded Octopus UI mounts.
///
/// Mirrors the iOS `OctopusInitialScreen` enum and the Android bridge-mode
/// composables (`OctopusPostDetailsScreen` / `OctopusGroupDetailsScreen`):
///
/// - [OctopusInitialScreen.mainFeed] — open the regular community feed with
///   the feed selector (the default).
/// - [OctopusInitialScreen.post] — open a specific post in **bridge mode**.
///   The user cannot navigate back to the main feed from this entry point;
///   they can dismiss the screen to return to the host app.
/// - [OctopusInitialScreen.group] — open a specific group's feed in bridge
///   mode. Same dismissal semantics as `.post`.
/// - [OctopusInitialScreen.createPost] — open the post editor as the initial
///   screen, optionally prefilled.
///
/// Passed via the `initialScreen:` parameter on [OctopusHomeScreen] /
/// [OctopusHomeContent].
///
/// ## Precedence
///
/// When a push-notification deep link (`OctopusNotification.linkPath`) is
/// supplied via the `notification:` parameter at the same mount, the deep
/// link **wins** — `initialScreen` is ignored. This matches iOS, where the
/// notification handler reroutes regardless of the initial screen requested.
@immutable
sealed class OctopusInitialScreen {
  const OctopusInitialScreen();

  /// The main feed screen with the feed selector. This is the default.
  const factory OctopusInitialScreen.mainFeed() = OctopusInitialScreenMainFeed;

  /// Open a specific post in bridge mode.
  const factory OctopusInitialScreen.post(PostScreenInfo info) =
      OctopusInitialScreenPost;

  /// Open a specific group's feed in bridge mode.
  const factory OctopusInitialScreen.group(GroupScreenInfo info) =
      OctopusInitialScreenGroup;

  /// Open the post editor, optionally prefilled with content supplied by the
  /// host app.
  ///
  /// **Image-bytes asymmetry.** When used via this embedded entry point,
  /// `OctopusPrefilledPost.image` bytes are **dropped** on both Android and
  /// iOS — the embedded route does not materialize image bytes through the
  /// PlatformView. Use [OctopusSDK.showOctopusCreatePostScreen] for the
  /// image-share flow. Text / topicId / CTA still pass through here.
  ///
  /// **CTA validation parity (minor).** iOS validates the CTA at decode time
  /// (empty label or unparseable URL silently degrades to a no-CTA editor +
  /// an `NSLog` notice); Android forwards the CTA primitives unchanged into
  /// the native editor, which validates at publish time. Hosts should
  /// supply a well-formed CTA on both platforms.
  const factory OctopusInitialScreen.createPost(CreatePostScreenInfo info) =
      OctopusInitialScreenCreatePost;

  /// The platform-channel representation handed to the native bridges.
  ///
  /// Wire shape: `{"type": "mainFeed"|"post"|"group"|"createPost", ...payload}`.
  Map<String, dynamic> toMap();
}

/// The main feed screen with the feed selector. See
/// [OctopusInitialScreen.mainFeed].
class OctopusInitialScreenMainFeed extends OctopusInitialScreen {
  const OctopusInitialScreenMainFeed();

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{'type': 'mainFeed'};

  @override
  bool operator ==(Object other) => other is OctopusInitialScreenMainFeed;

  @override
  int get hashCode => (OctopusInitialScreenMainFeed).hashCode;

  @override
  String toString() => 'OctopusInitialScreen.mainFeed()';
}

/// A specific post detail screen entry. See [OctopusInitialScreen.post].
class OctopusInitialScreenPost extends OctopusInitialScreen {
  /// The post to display.
  final PostScreenInfo info;

  const OctopusInitialScreenPost(this.info);

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'type': 'post',
        'postId': info.postId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OctopusInitialScreenPost && other.info == info;

  @override
  int get hashCode => Object.hash(OctopusInitialScreenPost, info);

  @override
  String toString() => 'OctopusInitialScreen.post($info)';
}

/// A specific group detail screen entry. See [OctopusInitialScreen.group].
class OctopusInitialScreenGroup extends OctopusInitialScreen {
  /// The group to display.
  final GroupScreenInfo info;

  const OctopusInitialScreenGroup(this.info);

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'type': 'group',
        'groupId': info.groupId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OctopusInitialScreenGroup && other.info == info;

  @override
  int get hashCode => Object.hash(OctopusInitialScreenGroup, info);

  @override
  String toString() => 'OctopusInitialScreen.group($info)';
}

/// The post editor as the initial screen. See
/// [OctopusInitialScreen.createPost].
class OctopusInitialScreenCreatePost extends OctopusInitialScreen {
  /// The prefill payload.
  final CreatePostScreenInfo info;

  const OctopusInitialScreenCreatePost(this.info);

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'type': 'createPost',
        ...info.toMap(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OctopusInitialScreenCreatePost && other.info == info;

  @override
  int get hashCode => Object.hash(OctopusInitialScreenCreatePost, info);

  @override
  String toString() => 'OctopusInitialScreen.createPost($info)';
}

/// Info needed to display a single post.
///
/// Mirrors the iOS `OctopusInitialScreen.PostScreenInfo` nested struct.
@immutable
class PostScreenInfo {
  /// The id of the post to display.
  final String postId;

  /// Creates the post-screen entry info.
  const PostScreenInfo({required this.postId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostScreenInfo && other.postId == postId;

  @override
  int get hashCode => postId.hashCode;

  @override
  String toString() => 'PostScreenInfo(postId: $postId)';
}

/// Info needed to display a single group's feed.
///
/// Mirrors the iOS `OctopusInitialScreen.GroupScreenInfo` nested struct.
@immutable
class GroupScreenInfo {
  /// The id of the group to display.
  final String groupId;

  /// Creates the group-screen entry info.
  const GroupScreenInfo({required this.groupId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupScreenInfo && other.groupId == groupId;

  @override
  int get hashCode => groupId.hashCode;

  @override
  String toString() => 'GroupScreenInfo(groupId: $groupId)';
}
