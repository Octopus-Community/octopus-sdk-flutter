// Supporting enums

enum ContentKind {
  post,
  comment,
  reply;

  static ContentKind fromString(String value) => switch (value) {
        'post' => ContentKind.post,
        'comment' => ContentKind.comment,
        'reply' => ContentKind.reply,
        _ => throw ArgumentError('Unknown ContentKind: $value'),
      };
}

enum ReactionKind {
  heart,
  joy,
  mouthOpen,
  clap,
  cry,
  rage,
  unknown;

  static ReactionKind fromString(String value) => switch (value) {
        'heart' => ReactionKind.heart,
        'joy' => ReactionKind.joy,
        'mouthOpen' => ReactionKind.mouthOpen,
        'clap' => ReactionKind.clap,
        'cry' => ReactionKind.cry,
        'rage' => ReactionKind.rage,
        _ => ReactionKind.unknown,
      };
}

enum ReportReason {
  hateSpeech,
  explicit,
  violence,
  spam,
  suicide,
  fakeProfile,
  childExploitation,
  intellectualProperty,
  other;

  static ReportReason fromString(String value) => switch (value) {
        'hateSpeech' => ReportReason.hateSpeech,
        'explicit' => ReportReason.explicit,
        'violence' => ReportReason.violence,
        'spam' => ReportReason.spam,
        'suicide' => ReportReason.suicide,
        'fakeProfile' => ReportReason.fakeProfile,
        'childExploitation' => ReportReason.childExploitation,
        'intellectualProperty' => ReportReason.intellectualProperty,
        _ => ReportReason.other,
      };
}

enum PostContent {
  text,
  image,
  poll;

  static PostContent fromString(String value) => switch (value) {
        'text' => PostContent.text,
        'image' => PostContent.image,
        'poll' => PostContent.poll,
        _ => throw ArgumentError('Unknown PostContent: $value'),
      };
}

enum PostClickedSource {
  feed,
  profile;

  static PostClickedSource fromString(String value) => switch (value) {
        'feed' => PostClickedSource.feed,
        'profile' => PostClickedSource.profile,
        _ => throw ArgumentError('Unknown PostClickedSource: $value'),
      };
}

enum GamificationPointsGainedAction {
  post,
  comment,
  reply,
  reaction,
  vote,
  postCommented,
  profileCompleted,
  dailySession;

  static GamificationPointsGainedAction fromString(String value) =>
      switch (value) {
        'post' => GamificationPointsGainedAction.post,
        'comment' => GamificationPointsGainedAction.comment,
        'reply' => GamificationPointsGainedAction.reply,
        'reaction' => GamificationPointsGainedAction.reaction,
        'vote' => GamificationPointsGainedAction.vote,
        'postCommented' => GamificationPointsGainedAction.postCommented,
        'profileCompleted' => GamificationPointsGainedAction.profileCompleted,
        'dailySession' => GamificationPointsGainedAction.dailySession,
        _ => throw ArgumentError(
            'Unknown GamificationPointsGainedAction: $value'),
      };
}

enum GamificationPointsRemovedAction {
  postDeleted,
  commentDeleted,
  replyDeleted,
  reactionDeleted;

  static GamificationPointsRemovedAction fromString(String value) =>
      switch (value) {
        'postDeleted' => GamificationPointsRemovedAction.postDeleted,
        'commentDeleted' => GamificationPointsRemovedAction.commentDeleted,
        'replyDeleted' => GamificationPointsRemovedAction.replyDeleted,
        'reactionDeleted' => GamificationPointsRemovedAction.reactionDeleted,
        _ => throw ArgumentError(
            'Unknown GamificationPointsRemovedAction: $value'),
      };
}

// Screen sealed class with associated data for some cases

sealed class Screen {
  const Screen();

  factory Screen.fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String;
    return switch (type) {
      'postsFeed' => PostsFeedScreen(
          feedId: map['feedId'] as String?,
          relatedTopicId: map['relatedTopicId'] as String?,
        ),
      'postDetail' => PostDetailScreen(postId: map['postId'] as String),
      'commentDetail' =>
        CommentDetailScreen(commentId: map['commentId'] as String),
      'createPost' => const CreatePostScreen(),
      'profile' => const ProfileScreen(),
      'otherUserProfile' =>
        OtherUserProfileScreen(profileId: map['profileId'] as String),
      'editProfile' => const EditProfileScreen(),
      'reportContent' => const ReportContentScreen(),
      'reportProfile' => const ReportProfileScreen(),
      'validateNickname' => const ValidateNicknameScreen(),
      'settingsList' => const SettingsListScreen(),
      'settingsAccount' => const SettingsAccountScreen(),
      'settingsAbout' => const SettingsAboutScreen(),
      'reportExplanation' => const ReportExplanationScreen(),
      'deleteAccount' => const DeleteAccountScreen(),
      _ => throw ArgumentError('Unknown Screen type: $type'),
    };
  }
}

class PostsFeedScreen extends Screen {
  final String? feedId;
  final String? relatedTopicId;
  const PostsFeedScreen({this.feedId, this.relatedTopicId});
}

class PostDetailScreen extends Screen {
  final String postId;
  const PostDetailScreen({required this.postId});
}

class CommentDetailScreen extends Screen {
  final String commentId;
  const CommentDetailScreen({required this.commentId});
}

class CreatePostScreen extends Screen {
  const CreatePostScreen();
}

class ProfileScreen extends Screen {
  const ProfileScreen();
}

class OtherUserProfileScreen extends Screen {
  final String profileId;
  const OtherUserProfileScreen({required this.profileId});
}

class EditProfileScreen extends Screen {
  const EditProfileScreen();
}

class ReportContentScreen extends Screen {
  const ReportContentScreen();
}

class ReportProfileScreen extends Screen {
  const ReportProfileScreen();
}

class ValidateNicknameScreen extends Screen {
  const ValidateNicknameScreen();
}

class SettingsListScreen extends Screen {
  const SettingsListScreen();
}

class SettingsAccountScreen extends Screen {
  const SettingsAccountScreen();
}

class SettingsAboutScreen extends Screen {
  const SettingsAboutScreen();
}

class ReportExplanationScreen extends Screen {
  const ReportExplanationScreen();
}

class DeleteAccountScreen extends Screen {
  const DeleteAccountScreen();
}

// Main event sealed class

sealed class OctopusEvent {
  const OctopusEvent();

  factory OctopusEvent.fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String;
    return switch (type) {
      'postCreated' => PostCreatedEvent(
          postId: map['postId'] as String,
          content: (map['content'] as List)
              .map((e) => PostContent.fromString(e as String))
              .toSet(),
          topicId: map['topicId'] as String?,
          textLength: map['textLength'] as int,
        ),
      'commentCreated' => CommentCreatedEvent(
          commentId: map['commentId'] as String,
          postId: map['postId'] as String,
          textLength: map['textLength'] as int,
        ),
      'replyCreated' => ReplyCreatedEvent(
          replyId: map['replyId'] as String,
          commentId: map['commentId'] as String,
          textLength: map['textLength'] as int,
        ),
      'contentDeleted' => ContentDeletedEvent(
          contentId: map['contentId'] as String,
          contentKind: ContentKind.fromString(map['contentKind'] as String),
        ),
      'reactionModified' => ReactionModifiedEvent(
          contentId: map['contentId'] as String,
          contentKind: ContentKind.fromString(map['contentKind'] as String),
          previousReaction: map['previousReaction'] != null
              ? ReactionKind.fromString(map['previousReaction'] as String)
              : null,
          newReaction: map['newReaction'] != null
              ? ReactionKind.fromString(map['newReaction'] as String)
              : null,
        ),
      'pollVoted' => PollVotedEvent(
          contentId: map['contentId'] as String,
          optionId: map['optionId'] as String,
        ),
      'contentReported' => ContentReportedEvent(
          contentId: map['contentId'] as String,
          reasons: (map['reasons'] as List)
              .map((e) => ReportReason.fromString(e as String))
              .toList(),
        ),
      'profileReported' => ProfileReportedEvent(
          profileId: map['profileId'] as String,
          reasons: (map['reasons'] as List)
              .map((e) => ReportReason.fromString(e as String))
              .toList(),
        ),
      'gamificationPointsGained' => GamificationPointsGainedEvent(
          points: map['points'] as int,
          action: GamificationPointsGainedAction.fromString(
              map['action'] as String),
        ),
      'gamificationPointsRemoved' => GamificationPointsRemovedEvent(
          points: map['points'] as int,
          action: GamificationPointsRemovedAction.fromString(
              map['action'] as String),
        ),
      'screenDisplayed' => ScreenDisplayedEvent(
          screen: Screen.fromMap(
            Map<String, dynamic>.from(map['screen'] as Map<dynamic, dynamic>),
          )
        ),
      'notificationClicked' => NotificationClickedEvent(
          notificationId: map['notificationId'] as String,
          contentId: map['contentId'] as String?,
        ),
      'postClicked' => PostClickedEvent(
          postId: map['postId'] as String,
          source:
              PostClickedSource.fromString(map['source'] as String),
        ),
      'translationButtonClicked' => TranslationButtonClickedEvent(
          contentId: map['contentId'] as String,
          viewTranslated: map['viewTranslated'] as bool,
          contentKind: ContentKind.fromString(map['contentKind'] as String),
        ),
      'commentButtonClicked' => CommentButtonClickedEvent(
          postId: map['postId'] as String,
        ),
      'replyButtonClicked' => ReplyButtonClickedEvent(
          commentId: map['commentId'] as String,
        ),
      'seeRepliesButtonClicked' => SeeRepliesButtonClickedEvent(
          commentId: map['commentId'] as String,
        ),
      'profileModified' => ProfileModifiedEvent(
          nicknameUpdated: map['nicknameUpdated'] as bool,
          bioUpdated: map['bioUpdated'] as bool,
          bioLength: map['bioLength'] as int?,
          pictureUpdated: map['pictureUpdated'] as bool,
          hasPicture: map['hasPicture'] as bool?,
        ),
      'sessionStarted' => SessionStartedEvent(
          sessionId: map['sessionId'] as String,
        ),
      'sessionStopped' => SessionStoppedEvent(
          sessionId: map['sessionId'] as String,
        ),
      _ => throw ArgumentError('Unknown OctopusEvent type: $type'),
    };
  }
}

// Content Events

class PostCreatedEvent extends OctopusEvent {
  final String postId;
  final Set<PostContent> content;
  final String? topicId;
  final int textLength;
  const PostCreatedEvent({
    required this.postId,
    required this.content,
    this.topicId,
    required this.textLength,
  });
}

class CommentCreatedEvent extends OctopusEvent {
  final String commentId;
  final String postId;
  final int textLength;
  const CommentCreatedEvent({
    required this.commentId,
    required this.postId,
    required this.textLength,
  });
}

class ReplyCreatedEvent extends OctopusEvent {
  final String replyId;
  final String commentId;
  final int textLength;
  const ReplyCreatedEvent({
    required this.replyId,
    required this.commentId,
    required this.textLength,
  });
}

class ContentDeletedEvent extends OctopusEvent {
  final String contentId;
  final ContentKind contentKind;
  const ContentDeletedEvent({
    required this.contentId,
    required this.contentKind,
  });
}

// Interaction Events

class ReactionModifiedEvent extends OctopusEvent {
  final String contentId;
  final ContentKind contentKind;
  final ReactionKind? previousReaction;
  final ReactionKind? newReaction;
  const ReactionModifiedEvent({
    required this.contentId,
    required this.contentKind,
    this.previousReaction,
    this.newReaction,
  });
}

class PollVotedEvent extends OctopusEvent {
  final String contentId;
  final String optionId;
  const PollVotedEvent({
    required this.contentId,
    required this.optionId,
  });
}

class ContentReportedEvent extends OctopusEvent {
  final String contentId;
  final List<ReportReason> reasons;
  const ContentReportedEvent({
    required this.contentId,
    required this.reasons,
  });
}

class ProfileReportedEvent extends OctopusEvent {
  final String profileId;
  final List<ReportReason> reasons;
  const ProfileReportedEvent({
    required this.profileId,
    required this.reasons,
  });
}

// Gamification Events

class GamificationPointsGainedEvent extends OctopusEvent {
  final int points;
  final GamificationPointsGainedAction action;
  const GamificationPointsGainedEvent({
    required this.points,
    required this.action,
  });
}

class GamificationPointsRemovedEvent extends OctopusEvent {
  final int points;
  final GamificationPointsRemovedAction action;
  const GamificationPointsRemovedEvent({
    required this.points,
    required this.action,
  });
}

// Navigation Events

class ScreenDisplayedEvent extends OctopusEvent {
  final Screen screen;
  const ScreenDisplayedEvent({required this.screen});
}

// Click Events

class NotificationClickedEvent extends OctopusEvent {
  final String notificationId;
  final String? contentId;
  const NotificationClickedEvent({
    required this.notificationId,
    this.contentId,
  });
}

class PostClickedEvent extends OctopusEvent {
  final String postId;
  final PostClickedSource source;
  const PostClickedEvent({
    required this.postId,
    required this.source,
  });
}

class TranslationButtonClickedEvent extends OctopusEvent {
  final String contentId;
  final bool viewTranslated;
  final ContentKind contentKind;
  const TranslationButtonClickedEvent({
    required this.contentId,
    required this.viewTranslated,
    required this.contentKind,
  });
}

class CommentButtonClickedEvent extends OctopusEvent {
  final String postId;
  const CommentButtonClickedEvent({required this.postId});
}

class ReplyButtonClickedEvent extends OctopusEvent {
  final String commentId;
  const ReplyButtonClickedEvent({required this.commentId});
}

class SeeRepliesButtonClickedEvent extends OctopusEvent {
  final String commentId;
  const SeeRepliesButtonClickedEvent({required this.commentId});
}

// Profile Events

class ProfileModifiedEvent extends OctopusEvent {
  final bool nicknameUpdated;
  final bool bioUpdated;
  final int? bioLength;
  final bool pictureUpdated;
  final bool? hasPicture;
  const ProfileModifiedEvent({
    required this.nicknameUpdated,
    required this.bioUpdated,
    this.bioLength,
    required this.pictureUpdated,
    this.hasPicture,
  });
}

// Session Events

class SessionStartedEvent extends OctopusEvent {
  final String sessionId;
  const SessionStartedEvent({required this.sessionId});
}

class SessionStoppedEvent extends OctopusEvent {
  final String sessionId;
  const SessionStoppedEvent({required this.sessionId});
}