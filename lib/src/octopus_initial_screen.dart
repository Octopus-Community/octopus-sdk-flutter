import 'package:flutter/foundation.dart' show immutable;

import 'create_post_screen_info.dart';
import 'member_id.dart';

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
/// - [OctopusInitialScreen.activity] — open one member's Octopus posts
///   (Unified Profile).
/// - [OctopusInitialScreen.profile] — open one member's Octopus profile, or
///   the connected user's own.
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

  /// Open the posts-only screen listing one member's Octopus posts
  /// (Unified Profile).
  ///
  /// Open it from your own profile screen — typically the one you show after
  /// intercepting a profile tap via [OctopusHomeScreen.onNavigateToProfile] —
  /// to surface that member's Octopus posts. Identify the member with
  /// [ActivityScreenInfo.clientUserId] (your app's own id) or
  /// [ActivityScreenInfo.profileId] (their Octopus profile id).
  ///
  /// The screen lists the member's posts under a "{author}'s Posts" title, with
  /// no profile header and no tabs. When the id resolves to the **connected
  /// user's own**, both platforms open their two-tab activity screen instead.
  ///
  /// This entry point does not depend on Unified Profile being active — that
  /// only governs the in-community floating-button switch.
  ///
  /// Surrounding whitespace in the id is ignored, and an id that is blank or
  /// whitespace-only names no member at all: both platforms open the main feed,
  /// since this screen has no own-user form to fall back to.
  const factory OctopusInitialScreen.activity(ActivityScreenInfo info) =
      OctopusInitialScreenActivity;

  /// Open a member's Octopus profile, or — with [clientUserId] left `null` —
  /// the connected user's own profile.
  ///
  /// [clientUserId] is **your app's own id** for the member (the one passed to
  /// SSO `connectUser`), resolved through the `GetPublicProfile`
  /// client-user-id lookup. It requires the community to expose client user
  /// ids; an id that does not resolve (unknown or stale mapping, network
  /// failure, or a community that does not expose client user ids) shows an
  /// error / unavailable state on both platforms — it never falls back to the
  /// connected user's own profile.
  ///
  /// Surrounding whitespace in [clientUserId] is ignored, and a blank or
  /// whitespace-only id counts as no id — the connected user's own profile,
  /// exactly as `null` does.
  ///
  /// [OctopusProfileScreen] is the ergonomic wrapper over this case; prefer it
  /// unless you are already passing an `initialScreen`.
  ///
  /// **This case has no counterpart in the native iOS `OctopusInitialScreen`
  /// enum** — iOS ships a separate top-level `OctopusProfileScreen` view, so
  /// the iOS bridge mounts that view instead of `OctopusHomeScreen` when it
  /// decodes this case (Android pushes its `ProfileSummary` /
  /// `CurrentUserProfileGraph` destination inside the same `NavHost` as the
  /// other bridge-mode entry points). Two consequences on iOS: the main-feed
  /// nav-bar title (`navBarTitle` / `titleCentered`) and the `notification`
  /// deep link are not applicable to the mounted view, and
  /// `bottomSafeAreaInset` is not forwarded — the native profile screen has no
  /// such parameter.
  ///
  /// **No by-Octopus-profile-id variant.** Android's native SDK also accepts a
  /// raw Octopus profile id here, iOS's `OctopusProfileScreen` does not, so the
  /// wrapper deliberately exposes only the client-user-id form that works on
  /// both. Use [OctopusInitialScreen.activity] with
  /// [ActivityScreenInfo.profileId] when all you hold is an Octopus id.
  const factory OctopusInitialScreen.profile({String? clientUserId}) =
      OctopusInitialScreenProfile;

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
  /// Wire shape:
  /// `{"type": "mainFeed"|"post"|"group"|"activity"|"profile"|"createPost", ...payload}`.
  ///
  /// The member-scoped cases (`activity`, `profile`) carry the **same** nested
  /// `{"member": {"source": "clientUserId"|"profileId", "id": ...}}` payload, so
  /// each bridge decodes them with one shared helper. The id is trimmed, and a
  /// blank one omits `member` entirely — which `profile` reads as the connected
  /// user's own profile and `activity` as the main feed.
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

/// One member's posts-only activity screen. See
/// [OctopusInitialScreen.activity].
class OctopusInitialScreenActivity extends OctopusInitialScreen {
  /// The member whose posts to display.
  final ActivityScreenInfo info;

  const OctopusInitialScreenActivity(this.info);

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        'type': 'activity',
        ...info.toMap(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OctopusInitialScreenActivity && other.info == info;

  @override
  int get hashCode => Object.hash(OctopusInitialScreenActivity, info);

  @override
  String toString() => 'OctopusInitialScreen.activity($info)';
}

/// A member's profile screen. See [OctopusInitialScreen.profile].
class OctopusInitialScreenProfile extends OctopusInitialScreen {
  /// The host app's own id for the member whose profile to display, or `null`
  /// for the connected user's own profile.
  final String? clientUserId;

  const OctopusInitialScreenProfile({this.clientUserId});

  @override
  Map<String, dynamic> toMap() {
    final id = clientUserId;
    // Absent `member` means "the connected user's own profile" — the same
    // meaning iOS gives `OctopusProfileScreen(clientUserId: nil)`. A blank id
    // is encoded as absent rather than sent as an id that could never resolve:
    // `memberIdToMap` returns null for it, so this branch also covers `''` and
    // `'   '`.
    final member =
        id == null ? null : memberIdToMap(MemberIdSource.clientUserId, id);
    return <String, dynamic>{
      'type': 'profile',
      if (member != null) 'member': member,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OctopusInitialScreenProfile &&
          other.clientUserId == clientUserId;

  @override
  int get hashCode => Object.hash(OctopusInitialScreenProfile, clientUserId);

  @override
  String toString() =>
      'OctopusInitialScreen.profile(clientUserId: $clientUserId)';
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

/// Info needed to display one member's posts-only activity screen.
///
/// Mirrors the iOS `OctopusInitialScreen.ActivityScreenInfo` struct: the member
/// is identified **either** by the host app's own id
/// ([ActivityScreenInfo.clientUserId]) **or** by their Octopus profile id
/// ([ActivityScreenInfo.profileId]) — never both, exactly like the two iOS
/// initializers.
@immutable
class ActivityScreenInfo {
  /// Which kind of id [_id] is. Private: the two named constructors are the
  /// API, and [clientUserId] / [profileId] read the choice back out.
  final MemberIdSource _source;

  /// The id itself, of the kind named by [_source].
  final String _id;

  /// Identify the member by the host app's own id for them (the id passed to
  /// SSO `connectUser`).
  ///
  /// Resolved to an Octopus profile through the `GetPublicProfile`
  /// client-user-id lookup, which requires the community to expose client user
  /// ids. When it cannot be resolved — unknown or stale mapping, or a community
  /// that does not expose client user ids — the screen shows its empty state
  /// rather than falling back to any other member.
  const ActivityScreenInfo.clientUserId(String clientUserId)
      : _source = MemberIdSource.clientUserId,
        _id = clientUserId;

  /// Identify the member by their Octopus profile id.
  ///
  /// Use this when you already hold the Octopus id (e.g. one surfaced by
  /// [OctopusSDK.fetchCommunityData]): the screen opens directly, with no
  /// client-user-id lookup and no `exposeClientUserId` requirement.
  const ActivityScreenInfo.profileId(String profileId)
      : _source = MemberIdSource.profileId,
        _id = profileId;

  /// The host app's own id for the member, or `null` when this info was built
  /// from an Octopus profile id.
  String? get clientUserId =>
      _source == MemberIdSource.clientUserId ? _id : null;

  /// The member's Octopus profile id, or `null` when this info was built from a
  /// host-app client user id.
  String? get profileId => _source == MemberIdSource.profileId ? _id : null;

  /// The platform-channel payload: `{"member": {"source": ..., "id": ...}}`.
  ///
  /// A blank id carries no `member` at all: there is no member to open, and
  /// this entry point has no own-user form to fall back to, so both platforms
  /// read the absence as "show the main feed" — unlike
  /// `OctopusInitialScreen.profile()`, where an absent member is the documented
  /// way to ask for the connected user's own profile.
  Map<String, dynamic> toMap() {
    final member = memberIdToMap(_source, _id);
    return <String, dynamic>{if (member != null) 'member': member};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityScreenInfo &&
          other._source == _source &&
          other._id == _id;

  @override
  int get hashCode => Object.hash(_source, _id);

  @override
  String toString() => 'ActivityScreenInfo(${_source.name}: $_id)';
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
