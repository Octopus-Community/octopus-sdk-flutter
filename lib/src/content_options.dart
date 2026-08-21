import 'package:flutter/foundation.dart' show immutable;

/// Per-content-type options governing what members may add when creating a
/// post.
///
/// Every flag defaults to `true`: unseeded content options keep today's
/// behaviour (pictures + polls enabled).
@immutable
class PostOptions {
  /// Whether members may attach pictures to a post.
  final bool enablePictures;

  /// Whether members may attach a poll to a post.
  final bool enablePolls;

  /// Creates a [PostOptions]. Both flags default to `true`.
  const PostOptions({this.enablePictures = true, this.enablePolls = true});

  /// The platform-channel representation handed to the native bridges.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'enablePictures': enablePictures,
        'enablePolls': enablePolls,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostOptions &&
          other.enablePictures == enablePictures &&
          other.enablePolls == enablePolls;

  @override
  int get hashCode => Object.hash(enablePictures, enablePolls);

  @override
  String toString() =>
      'PostOptions(enablePictures: $enablePictures, enablePolls: $enablePolls)';
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

/// Per-content-type options governing what members may add when creating
/// content.
///
/// Internal test affordance mirroring the native SDKs' debug-only
/// `debugOverrideContentOptions` (Android `@InternalOctopusApi`, iOS
/// `@_spi(OctopusInternalTesting)`): it locally overrides the per-content-type
/// content options without a backend-driven config, for exercising the
/// pictures/polls creation gating in development builds and the sample app.
/// **Not part of the supported public API** — it may change or be removed at
/// any time.
///
/// Every flag defaults to `true`: an unseeded [ContentOptions] keeps today's
/// behaviour (pictures + polls enabled). A `false` value hides the matching
/// creation affordance — it governs *creation*, not the display of existing
/// content.
@immutable
class ContentOptions {
  /// Options for post creation.
  final PostOptions post;

  /// Options for comment creation.
  final CommentOptions comment;

  /// Options for reply creation.
  final ReplyOptions reply;

  /// Creates a [ContentOptions]. Every field defaults to every flag enabled
  /// (today's behaviour).
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
