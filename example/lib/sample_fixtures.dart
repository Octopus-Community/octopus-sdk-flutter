import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

/// Default content ids in the demo community the sample targets.
///
/// Demo content can expire, so an id here is not guaranteed to resolve: if one
/// no longer does, override it (scenario input or `--dart-define`, below).
/// Credentials stay in the demo configuration.
class SampleFixtures {
  const SampleFixtures({
    this.postText = const String.fromEnvironment(
      'OCTOPUS_DEMO_POST_ID',
      defaultValue: 'SfEDTqxLavmbCEcEO6CBRp',
    ),
    this.commentOnPost = const String.fromEnvironment(
      'OCTOPUS_DEMO_COMMENT_ID',
      defaultValue: 'v_iqL4I1Scdfv3OfJeINO1',
    ),
    this.userOther = const String.fromEnvironment(
      'OCTOPUS_DEMO_PROFILE_ID',
      defaultValue: 'FHjwxMQBGmSAD4KJxQk7uP',
    ),
    this.topicDefault = const String.fromEnvironment(
      'OCTOPUS_DEMO_TOPIC_ID',
      defaultValue: 'PMYFiz0sv6cKEcpMkq5qlT',
    ),
    this.postReactionStack = const String.fromEnvironment(
      'OCTOPUS_DEMO_REACTION_POST_ID',
      defaultValue: String.fromEnvironment(
        'OCTOPUS_DEMO_POST_ID',
        defaultValue: 'piWm_vjBa43SEOTexuz8ye',
      ),
    ),
    this.postImage,
    this.postPoll,
    this.postCta,
    this.commentReported,
    this.topicGated,
    this.deeplinkPost,
  });

  // Precedence: editable scenario input > --dart-define override > built-in
  // default. Defines are compile-time; existing input fields retarget at runtime.
  // The reaction-specific override wins over the legacy shared post override.
  final String postText;
  final String commentOnPost;
  final String userOther;
  final String topicDefault;
  final String postReactionStack;

  // No default target yet. Never substitute invented IDs or an unverified URL.
  final String? postImage;
  final String? postPoll;
  final String? postCta;
  final String? commentReported;
  final String? topicGated;
  final String? deeplinkPost;

  /// Prefer the fixture only when it exists in the active community.
  String? defaultGroupId(List<OctopusGroup> groups) {
    for (final group in groups) {
      if (group.id == topicDefault) return group.id;
    }
    for (final group in groups) {
      if (group.name == 'General') return group.id;
    }
    return groups.isEmpty ? null : groups.first.id;
  }

  /// Synthetic push payload for the presentation presets, not an external URL.
  Map<String, String> get postNotificationPayload {
    final id = postText.trim();
    if (id.isEmpty) throw StateError('post.text fixture is empty');
    return {
      'is_octopus_notification': 'true',
      'title': 'New activity in the demo community',
      'body': 'Tap to open the post this notification points at.',
      'link_path': 'post/$id',
      'post_id': id,
    };
  }
}

const sampleFixtures = SampleFixtures();
