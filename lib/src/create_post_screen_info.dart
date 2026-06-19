import 'package:flutter/foundation.dart' show immutable;

import 'octopus_prefilled_post.dart';

/// Info needed to open the Octopus post editor as an SDK entry point
/// (Bridge Share).
///
/// When [prefilledPost] is `null`, the editor opens empty — equivalent to the
/// regular in-SDK new-post flow. When non-null, the editor opens prefilled with
/// the provided text / image / group / CTA.
///
/// Mirrors the native `CreatePostScreenInfo` (a top-level type on Android; the
/// `OctopusInitialScreen.CreatePostScreenInfo` nested type on iOS).
@immutable
class CreatePostScreenInfo {
  /// The prefill payload, or `null` for an empty editor.
  final OctopusPrefilledPost? prefilledPost;

  /// Creates the create-post-screen entry info.
  const CreatePostScreenInfo({this.prefilledPost});

  /// The platform-channel representation handed to the native bridges.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'prefilledPost': prefilledPost?.toMap(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreatePostScreenInfo && other.prefilledPost == prefilledPost;

  @override
  int get hashCode => prefilledPost.hashCode;

  @override
  String toString() => 'CreatePostScreenInfo(prefilledPost: $prefilledPost)';
}
