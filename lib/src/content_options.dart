import 'package:flutter/foundation.dart' show immutable;

/// Options governing post creation and navigation when tapping a post.
///
/// Creation flags default to `true`; optional tap behaviours default to `false`.
@immutable
class PostOptions {
  /// Whether members may attach pictures to a post.
  final bool enablePictures;

  /// Whether members may attach a poll to a post.
  final bool enablePolls;

  /// Whether a post must contain text. Defaults to `true`.
  ///
  /// When `false`, an image (with or without a poll) can be published without
  /// text. A poll alone still needs text; nonblank text keeps native length
  /// validation. The backend must also allow posts without text.
  final bool textRequired;

  /// Whether tapping a feed image opens the post when its card opens the detail.
  ///
  /// Defaults to `false`. Images still open fullscreen when the card only
  /// expands its text, and always in the post detail.
  final bool imageTapOpensPost;

  /// Whether tapping a post's group name opens that group in feeds and detail.
  ///
  /// Defaults to `false`. Members without access follow the native groups
  /// list's access-denied flow.
  final bool groupNameTapOpensGroup;

  /// Creates options with creation enabled and optional tap behaviours disabled.
  const PostOptions({
    this.enablePictures = true,
    this.enablePolls = true,
    this.textRequired = true,
    this.imageTapOpensPost = false,
    this.groupNameTapOpensGroup = false,
  });

  /// The platform-channel representation handed to the native bridges.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'enablePictures': enablePictures,
    'enablePolls': enablePolls,
    'textRequired': textRequired,
    'imageTapOpensPost': imageTapOpensPost,
    'groupNameTapOpensGroup': groupNameTapOpensGroup,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostOptions &&
          other.enablePictures == enablePictures &&
          other.enablePolls == enablePolls &&
          other.textRequired == textRequired &&
          other.imageTapOpensPost == imageTapOpensPost &&
          other.groupNameTapOpensGroup == groupNameTapOpensGroup;

  @override
  int get hashCode => Object.hash(
    enablePictures,
    enablePolls,
    textRequired,
    imageTapOpensPost,
    groupNameTapOpensGroup,
  );

  @override
  String toString() =>
      'PostOptions(enablePictures: $enablePictures, enablePolls: $enablePolls, textRequired: $textRequired, imageTapOpensPost: $imageTapOpensPost, groupNameTapOpensGroup: $groupNameTapOpensGroup)';
}

/// Per-content-type options governing what members may add when creating a
/// comment.
///
/// Defaults to `true`: unseeded content options keep today's behaviour
/// (pictures enabled).
@immutable
class CommentOptions {
  /// Whether members may attach pictures to a comment.
  final bool enablePictures;

  /// Creates a [CommentOptions]. Defaults to `true`.
  const CommentOptions({this.enablePictures = true});

  /// The platform-channel representation handed to the native bridges.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'enablePictures': enablePictures,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommentOptions && other.enablePictures == enablePictures;

  @override
  int get hashCode => enablePictures.hashCode;

  @override
  String toString() => 'CommentOptions(enablePictures: $enablePictures)';
}

/// Per-content-type options governing what members may add when creating a
/// reply.
///
/// Defaults to `true`: unseeded content options keep today's behaviour
/// (pictures enabled).
@immutable
class ReplyOptions {
  /// Whether members may attach pictures to a reply.
  final bool enablePictures;

  /// Creates a [ReplyOptions]. Defaults to `true`.
  const ReplyOptions({this.enablePictures = true});

  /// The platform-channel representation handed to the native bridges.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'enablePictures': enablePictures,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReplyOptions && other.enablePictures == enablePictures;

  @override
  int get hashCode => enablePictures.hashCode;

  @override
  String toString() => 'ReplyOptions(enablePictures: $enablePictures)';
}

/// Per-content-type options governing content creation and post tap navigation.
///
/// Internal test affordance mirroring the native SDKs' debug-only
/// `debugOverrideContentOptions` (Android `@InternalOctopusApi`, iOS
/// `@_spi(OctopusInternalTesting)`): it locally overrides the per-content-type
/// content options without a backend-driven config, for exercising the
/// pictures/polls creation gating and post taps in development builds and the
/// sample app.
/// **Not part of the supported public API** — it may change or be removed at
/// any time.
///
/// Creation flags default to `true`; a `false` value hides the matching creation
/// affordance without hiding existing content. Post tap flags default to `false`,
/// preserving native navigation. Production uses the community configuration.
@immutable
class ContentOptions {
  /// Options for post creation and tap navigation.
  final PostOptions post;

  /// Options for comment creation.
  final CommentOptions comment;

  /// Options for reply creation.
  final ReplyOptions reply;

  /// Creates options with creation enabled and optional post taps disabled.
  const ContentOptions({
    this.post = const PostOptions(),
    this.comment = const CommentOptions(),
    this.reply = const ReplyOptions(),
  });

  /// The platform-channel representation handed to the native bridges.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'post': post.toMap(),
    'comment': comment.toMap(),
    'reply': reply.toMap(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContentOptions &&
          other.post == post &&
          other.comment == comment &&
          other.reply == reply;

  @override
  int get hashCode => Object.hash(post, comment, reply);

  @override
  String toString() =>
      'ContentOptions(post: $post, comment: $comment, reply: $reply)';
}
