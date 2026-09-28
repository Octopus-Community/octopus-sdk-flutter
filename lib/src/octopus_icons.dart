import 'dart:convert';

import 'package:flutter/services.dart';

/// An image for a native icon or screen-state illustration.
/// Tinted icons need transparency (PNG/WebP with an alpha channel, not JPEG).
///
/// Use small square images (ideally 24×24 points with transparent borders).
/// Icons are tinted; reactions and screen-state illustrations retain their colors.
/// Invalid image data keeps the native default. SVG and animated images are not
/// supported. Download remote images in your app, then use [OctopusIconSource.bytes].
class OctopusIconSource {
  /// Creates an image from raw base64 or a base64 `data:` URI.
  const OctopusIconSource.base64(this.base64);

  /// Encodes image bytes for transport to the native SDKs.
  /// Use PNG/WebP with alpha for tinted icons; JPEG is suitable for reactions
  /// and illustrations only.
  factory OctopusIconSource.bytes(Uint8List bytes) =>
      OctopusIconSource.base64(base64Encode(bytes));

  /// Loads an asset declared in the application's `pubspec.yaml`.
  ///
  /// Uses the exact asset key, without density-variant selection. For package
  /// assets use `packages/<package>/<path>`. Loading errors are propagated.
  static Future<OctopusIconSource> asset(String key,
      {AssetBundle? bundle}) async {
    final data = await (bundle ?? rootBundle).load(key);
    return OctopusIconSource.bytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  /// Encoded image transported to the native bridges.
  final String base64;
}

/// The complete on/off images of a radio button, checkbox or toggle.
class OctopusIconOnOff {
  /// Displayed when the control is on.
  final OctopusIconSource on;

  /// Displayed when the control is off.
  final OctopusIconSource off;

  /// Creates a complete pair; both images must decode or the default pair is used.
  const OctopusIconOnOff({
    required this.on,
    required this.off,
  });

  Map<String, String> _flatten(String prefix) => {
        '${prefix}on': on.base64,
        '${prefix}off': off.base64,
      };
}

/// Icons for choosing a group and navigating to its contents.
class OctopusGroupsIcons {
  /// Opens the list of groups (the topic selector).
  final OctopusIconSource? openList;

  /// Marks the selected group in a list.
  final OctopusIconSource? selected;

  /// Opens a group from a content.
  final OctopusIconSource? viewGroup;

  /// Creates optional icon overrides.
  const OctopusGroupsIcons({
    this.openList,
    this.selected,
    this.viewGroup,
  });

  Map<String, String> _flatten(String prefix) => {
        if (openList != null) '${prefix}openList': openList!.base64,
        if (selected != null) '${prefix}selected': selected!.base64,
        if (viewGroup != null) '${prefix}viewGroup': viewGroup!.base64,
      };
}

/// Actions in the native post composer, including pictures and polls.
class OctopusPostCreationIcons {
  /// Opens the post creation screen. On Android this is the "create post" button.
  final OctopusIconSource? open;

  /// Opens the group (topic) selection of the post being written.
  final OctopusIconSource? topicSelection;

  /// Adds a picture to the post.
  final OctopusIconSource? addPicture;

  /// Removes the picture of the post.
  final OctopusIconSource? deletePicture;

  /// Adds a poll to the post.
  final OctopusIconSource? addPoll;

  /// Adds an option to the poll.
  /// Android 1.14.1 does not render this override.
  final OctopusIconSource? addPollOption;

  /// Removes the poll.
  final OctopusIconSource? deletePoll;

  /// Removes a poll option.
  /// Android 1.14.1 does not render this override.
  final OctopusIconSource? deletePollOption;

  /// Creates optional icon overrides.
  const OctopusPostCreationIcons({
    this.open,
    this.topicSelection,
    this.addPicture,
    this.deletePicture,
    this.addPoll,
    this.addPollOption,
    this.deletePoll,
    this.deletePollOption,
  });

  Map<String, String> _flatten(String prefix) => {
        if (open != null) '${prefix}open': open!.base64,
        if (topicSelection != null)
          '${prefix}topicSelection': topicSelection!.base64,
        if (addPicture != null) '${prefix}addPicture': addPicture!.base64,
        if (deletePicture != null)
          '${prefix}deletePicture': deletePicture!.base64,
        if (addPoll != null) '${prefix}addPoll': addPoll!.base64,
        if (addPollOption != null)
          '${prefix}addPollOption': addPollOption!.base64,
        if (deletePoll != null) '${prefix}deletePoll': deletePoll!.base64,
        if (deletePollOption != null)
          '${prefix}deletePollOption': deletePollOption!.base64,
      };
}

/// Post actions and legacy empty-feed illustrations.
class OctopusPostIcons {
  /// Icons of the post creation screen.
  final OctopusPostCreationIcons? creation;

  /// Illustration of an empty group feed.
  /// Both Android 1.14.1 and iOS 1.14.0 render `screenStates.emptyContent`
  /// for this screen instead; this field preserves the native public surface.
  final OctopusIconSource? emptyFeedInGroups;

  /// Illustration of the current user's empty post feed on their profile.
  /// Both Android 1.14.1 and iOS 1.14.0 render `screenStates.emptyContent`
  /// for this screen instead; this field preserves the native public surface.
  final OctopusIconSource? emptyFeedInCurrentUserProfile;

  /// Illustration of another user's empty post feed on their profile.
  /// Both Android 1.14.1 and iOS 1.14.0 render `screenStates.emptyContent`
  /// for this screen instead; this field preserves the native public surface.
  final OctopusIconSource? emptyFeedInOtherUserProfile;

  /// Shown in place of a post that is no longer available.
  final OctopusIconSource? notAvailable;

  /// Next to the comment count of a post.
  /// Neither native SDK renders this slot at Android 1.14.1 / iOS 1.14.0.
  final OctopusIconSource? commentCount;

  /// Next to the view count of a post.
  /// Neither native SDK renders this slot at Android 1.14.1 / iOS 1.14.0.
  final OctopusIconSource? viewCount;

  /// Opens the full reaction picker.
  /// Neither native SDK renders this slot at Android 1.14.1 / iOS 1.14.0.
  final OctopusIconSource? moreReactions;

  /// The like button when the current user has not reacted.
  final OctopusIconSource? likeNotSelected;

  /// Shown on a moderated post.
  final OctopusIconSource? moderated;

  /// Creates optional icon overrides.
  const OctopusPostIcons({
    this.creation,
    this.emptyFeedInGroups,
    this.emptyFeedInCurrentUserProfile,
    this.emptyFeedInOtherUserProfile,
    this.notAvailable,
    this.commentCount,
    this.viewCount,
    this.moreReactions,
    this.likeNotSelected,
    this.moderated,
  });

  Map<String, String> _flatten(String prefix) => {
        if (creation != null) ...creation!._flatten('${prefix}creation.'),
        if (emptyFeedInGroups != null)
          '${prefix}emptyFeedInGroups': emptyFeedInGroups!.base64,
        if (emptyFeedInCurrentUserProfile != null)
          '${prefix}emptyFeedInCurrentUserProfile':
              emptyFeedInCurrentUserProfile!.base64,
        if (emptyFeedInOtherUserProfile != null)
          '${prefix}emptyFeedInOtherUserProfile':
              emptyFeedInOtherUserProfile!.base64,
        if (notAvailable != null) '${prefix}notAvailable': notAvailable!.base64,
        if (commentCount != null) '${prefix}commentCount': commentCount!.base64,
        if (viewCount != null) '${prefix}viewCount': viewCount!.base64,
        if (moreReactions != null)
          '${prefix}moreReactions': moreReactions!.base64,
        if (likeNotSelected != null)
          '${prefix}likeNotSelected': likeNotSelected!.base64,
        if (moderated != null) '${prefix}moderated': moderated!.base64,
      };
}

/// Actions for opening the comment composer, sending text and attaching pictures.
class OctopusCommentCreationIcons {
  /// The "comment" action of a post, which opens the comment field.
  final OctopusIconSource? open;

  /// Sends the comment.
  final OctopusIconSource? create;

  /// Adds a picture to the comment.
  final OctopusIconSource? addPicture;

  /// Removes the picture of the comment.
  final OctopusIconSource? deletePicture;

  /// Creates optional icon overrides.
  const OctopusCommentCreationIcons({
    this.open,
    this.create,
    this.addPicture,
    this.deletePicture,
  });

  Map<String, String> _flatten(String prefix) => {
        if (open != null) '${prefix}open': open!.base64,
        if (create != null) '${prefix}create': create!.base64,
        if (addPicture != null) '${prefix}addPicture': addPicture!.base64,
        if (deletePicture != null)
          '${prefix}deletePicture': deletePicture!.base64,
      };
}

/// Comment actions and legacy empty-comment illustrations.
class OctopusCommentIcons {
  /// Icons of the comment creation field.
  final OctopusCommentCreationIcons? creation;

  /// Illustration of a post without comments.
  /// Both Android 1.14.1 and iOS 1.14.0 render `screenStates.emptyContent`
  /// for this screen instead; this field preserves the native public surface.
  final OctopusIconSource? emptyFeed;

  /// Shown in place of a comment that is no longer available.
  final OctopusIconSource? notAvailable;

  /// Opens the replies of a comment.
  final OctopusIconSource? seeReply;

  /// The like button of a comment when the current user has not reacted.
  final OctopusIconSource? likeNotSelected;

  /// Creates optional icon overrides.
  const OctopusCommentIcons({
    this.creation,
    this.emptyFeed,
    this.notAvailable,
    this.seeReply,
    this.likeNotSelected,
  });

  Map<String, String> _flatten(String prefix) => {
        if (creation != null) ...creation!._flatten('${prefix}creation.'),
        if (emptyFeed != null) '${prefix}emptyFeed': emptyFeed!.base64,
        if (notAvailable != null) '${prefix}notAvailable': notAvailable!.base64,
        if (seeReply != null) '${prefix}seeReply': seeReply!.base64,
        if (likeNotSelected != null)
          '${prefix}likeNotSelected': likeNotSelected!.base64,
      };
}

/// Actions for opening the reply composer, sending text and attaching pictures.
class OctopusReplyCreationIcons {
  /// The "reply" action of a comment, which opens the reply field.
  final OctopusIconSource? open;

  /// Sends the reply.
  final OctopusIconSource? create;

  /// Adds a picture to the reply.
  final OctopusIconSource? addPicture;

  /// Removes the picture of the reply.
  final OctopusIconSource? deletePicture;

  /// Creates optional icon overrides.
  const OctopusReplyCreationIcons({
    this.open,
    this.create,
    this.addPicture,
    this.deletePicture,
  });

  Map<String, String> _flatten(String prefix) => {
        if (open != null) '${prefix}open': open!.base64,
        if (create != null) '${prefix}create': create!.base64,
        if (addPicture != null) '${prefix}addPicture': addPicture!.base64,
        if (deletePicture != null)
          '${prefix}deletePicture': deletePicture!.base64,
      };
}

/// Reply composition and like-button icons.
class OctopusReplyIcons {
  /// Icons of the reply creation field.
  final OctopusReplyCreationIcons? creation;

  /// The like button of a reply when the current user has not reacted.
  final OctopusIconSource? likeNotSelected;

  /// Creates optional icon overrides.
  const OctopusReplyIcons({
    this.creation,
    this.likeNotSelected,
  });

  Map<String, String> _flatten(String prefix) => {
        if (creation != null) ...creation!._flatten('${prefix}creation.'),
        if (likeNotSelected != null)
          '${prefix}likeNotSelected': likeNotSelected!.base64,
      };
}

/// Playback and sound controls in the native video player.
class OctopusVideoIcons {
  /// Shown while the sound is off.
  final OctopusIconSource? muted;

  /// Shown while the sound is on.
  final OctopusIconSource? notMuted;

  /// Pauses the video.
  final OctopusIconSource? pause;

  /// Plays the video.
  final OctopusIconSource? play;

  /// Replays the video once it has ended.
  final OctopusIconSource? replay;

  /// Creates optional icon overrides.
  const OctopusVideoIcons({
    this.muted,
    this.notMuted,
    this.pause,
    this.play,
    this.replay,
  });

  Map<String, String> _flatten(String prefix) => {
        if (muted != null) '${prefix}muted': muted!.base64,
        if (notMuted != null) '${prefix}notMuted': notMuted!.base64,
        if (pause != null) '${prefix}pause': pause!.base64,
        if (play != null) '${prefix}play': play!.base64,
        if (replay != null) '${prefix}replay': replay!.base64,
      };
}

/// The selection indicator for a poll option.
class OctopusPollIcons {
  /// Marks the option the current user voted for.
  final OctopusIconSource? selectedOption;

  /// Creates optional icon overrides.
  const OctopusPollIcons({
    this.selectedOption,
  });

  Map<String, String> _flatten(String prefix) => {
        if (selectedOption != null)
          '${prefix}selectedOption': selectedOption!.base64,
      };
}

/// The six reaction images, rendered in their original colors without tinting.
class OctopusReactionIcons {
  /// The heart reaction (also the "liked" state of the like button).
  final OctopusIconSource? heart;

  /// The tears-of-joy reaction.
  final OctopusIconSource? joy;

  /// The open-mouth (surprised) reaction.
  final OctopusIconSource? mouthOpen;

  /// The clapping-hands reaction.
  final OctopusIconSource? clap;

  /// The crying reaction.
  final OctopusIconSource? cry;

  /// The angry reaction.
  final OctopusIconSource? rage;

  /// Creates optional icon overrides.
  const OctopusReactionIcons({
    this.heart,
    this.joy,
    this.mouthOpen,
    this.clap,
    this.cry,
    this.rage,
  });

  Map<String, String> _flatten(String prefix) => {
        if (heart != null) '${prefix}heart': heart!.base64,
        if (joy != null) '${prefix}joy': joy!.base64,
        if (mouthOpen != null) '${prefix}mouthOpen': mouthOpen!.base64,
        if (clap != null) '${prefix}clap': clap!.base64,
        if (cry != null) '${prefix}cry': cry!.base64,
        if (rage != null) '${prefix}rage': rage!.base64,
      };
}

/// Icons for posts, comments, replies, media and content actions.
class OctopusContentIcons {
  /// Post icons.
  final OctopusPostIcons? post;

  /// Comment icons.
  final OctopusCommentIcons? comment;

  /// Reply icons.
  final OctopusReplyIcons? reply;

  /// Video player icons.
  final OctopusVideoIcons? video;

  /// Poll icons.
  final OctopusPollIcons? poll;

  /// Reaction images, drawn in their original colors (not tinted).
  final OctopusReactionIcons? reaction;

  /// The "delete" action of a content.
  final OctopusIconSource? delete;

  /// The "report" action of a content.
  final OctopusIconSource? report;

  /// Creates optional icon overrides.
  const OctopusContentIcons({
    this.post,
    this.comment,
    this.reply,
    this.video,
    this.poll,
    this.reaction,
    this.delete,
    this.report,
  });

  Map<String, String> _flatten(String prefix) => {
        if (post != null) ...post!._flatten('${prefix}post.'),
        if (comment != null) ...comment!._flatten('${prefix}comment.'),
        if (reply != null) ...reply!._flatten('${prefix}reply.'),
        if (video != null) ...video!._flatten('${prefix}video.'),
        if (poll != null) ...poll!._flatten('${prefix}poll.'),
        if (reaction != null) ...reaction!._flatten('${prefix}reaction.'),
        if (delete != null) '${prefix}delete': delete!.base64,
        if (report != null) '${prefix}report': report!.base64,
      };
}

/// Badges and actions in the levels and gamification rules screens.
class OctopusGamificationIcons {
  /// The badge of a user, tinted with the color of their level.
  final OctopusIconSource? badge;

  /// Opens the gamification rules.
  final OctopusIconSource? info;

  /// Illustration at the top of the gamification rules.
  /// iOS 1.14.0 uses [badge] here instead, ignoring this override.
  final OctopusIconSource? rulesHeader;

  /// Creates optional icon overrides.
  const OctopusGamificationIcons({
    this.badge,
    this.info,
    this.rulesHeader,
  });

  Map<String, String> _flatten(String prefix) => {
        if (badge != null) '${prefix}badge': badge!.base64,
        if (info != null) '${prefix}info': info!.base64,
        if (rulesHeader != null) '${prefix}rulesHeader': rulesHeader!.base64,
      };
}

/// Icons for account, help, information and sign-out actions.
class OctopusSettingsIcons {
  /// The account entry.
  final OctopusIconSource? account;

  /// The help entry.
  final OctopusIconSource? help;

  /// The information entry.
  final OctopusIconSource? info;

  /// The logout entry.
  final OctopusIconSource? logout;

  /// The warning shown before an account deletion.
  final OctopusIconSource? deleteAccountWarning;

  /// Creates optional icon overrides.
  const OctopusSettingsIcons({
    this.account,
    this.help,
    this.info,
    this.logout,
    this.deleteAccountWarning,
  });

  Map<String, String> _flatten(String prefix) => {
        if (account != null) '${prefix}account': account!.base64,
        if (help != null) '${prefix}help': help!.base64,
        if (info != null) '${prefix}info': info!.base64,
        if (logout != null) '${prefix}logout': logout!.base64,
        if (deleteAccountWarning != null)
          '${prefix}deleteAccountWarning': deleteAccountWarning!.base64,
      };
}

/// Profile editing actions and legacy profile illustrations.
class OctopusProfileIcons {
  /// Adds a profile picture.
  final OctopusIconSource? addPicture;

  /// Edits the profile picture.
  final OctopusIconSource? editPicture;

  /// Adds a bio.
  final OctopusIconSource? addBio;

  /// Illustration of an empty notification list.
  /// Both Android 1.14.1 and iOS 1.14.0 render `screenStates.emptyNotifications`
  /// for this screen instead; this field preserves the native public surface.
  final OctopusIconSource? emptyNotifications;

  /// Reports a profile.
  final OctopusIconSource? report;

  /// The avatar shown when the user is not connected (error state).
  final OctopusIconSource? notConnected;

  /// Blocks a user.
  final OctopusIconSource? blockUser;

  /// Creates optional icon overrides.
  const OctopusProfileIcons({
    this.addPicture,
    this.editPicture,
    this.addBio,
    this.emptyNotifications,
    this.report,
    this.notConnected,
    this.blockUser,
  });

  Map<String, String> _flatten(String prefix) => {
        if (addPicture != null) '${prefix}addPicture': addPicture!.base64,
        if (editPicture != null) '${prefix}editPicture': editPicture!.base64,
        if (addBio != null) '${prefix}addBio': addBio!.base64,
        if (emptyNotifications != null)
          '${prefix}emptyNotifications': emptyNotifications!.base64,
        if (report != null) '${prefix}report': report!.base64,
        if (notConnected != null) '${prefix}notConnected': notConnected!.base64,
        if (blockUser != null) '${prefix}blockUser': blockUser!.base64,
      };
}

/// Shared navigation, activity and two-state control icons.
class OctopusCommonIcons {
  /// Radio button pair. Absent: the native default pair (the platform widget on Android).
  final OctopusIconOnOff? radio;

  /// Checkbox pair. Absent: the native default pair.
  /// Android 1.14.1 uses its platform checkbox and ignores this override.
  final OctopusIconOnOff? checkbox;

  /// Toggle pair. Absent: the native default pair (the platform switch on Android).
  final OctopusIconOnOff? toggle;

  /// The overflow "more actions" button.
  final OctopusIconSource? moreActions;

  /// The activity button, shown in place of the connected user's avatar on the home floating
  /// button when Unified Profile is active.
  final OctopusIconSource? activityButton;

  /// The navigation indicator (right arrow) of list cells.
  final OctopusIconSource? listCellNavIndicator;

  /// Creates optional icon overrides.
  const OctopusCommonIcons({
    this.radio,
    this.checkbox,
    this.toggle,
    this.moreActions,
    this.activityButton,
    this.listCellNavIndicator,
  });

  Map<String, String> _flatten(String prefix) => {
        if (radio != null) ...radio!._flatten('${prefix}radio.'),
        if (checkbox != null) ...checkbox!._flatten('${prefix}checkbox.'),
        if (toggle != null) ...toggle!._flatten('${prefix}toggle.'),
        if (moreActions != null) '${prefix}moreActions': moreActions!.base64,
        if (activityButton != null)
          '${prefix}activityButton': activityButton!.base64,
        if (listCellNavIndicator != null)
          '${prefix}listCellNavIndicator': listCellNavIndicator!.base64,
      };
}

/// Optional icon overrides; omitted slots retain the native defaults.
/// Names follow iOS `OctopusTheme.Assets.Icons`. Pass to `OctopusTheme.icons`.
class OctopusIcons {
  /// Group (topic) icons.
  final OctopusGroupsIcons? groups;

  /// Content icons: posts, comments, replies, video, polls and reactions.
  final OctopusContentIcons? content;

  /// Gamification icons.
  final OctopusGamificationIcons? gamification;

  /// Settings icons.
  final OctopusSettingsIcons? settings;

  /// Profile and notification icons.
  final OctopusProfileIcons? profile;

  /// Icons shared across screens.
  final OctopusCommonIcons? common;

  /// Full-color illustrations for empty screens and failed first loads.
  final OctopusScreenStateIcons? screenStates;

  /// Creates optional icon overrides.
  const OctopusIcons({
    this.groups,
    this.content,
    this.gamification,
    this.settings,
    this.profile,
    this.common,
    this.screenStates,
  });

  Map<String, String> _flatten(String prefix) => {
        if (groups != null) ...groups!._flatten('${prefix}groups.'),
        if (content != null) ...content!._flatten('${prefix}content.'),
        if (gamification != null)
          ...gamification!._flatten('${prefix}gamification.'),
        if (settings != null) ...settings!._flatten('${prefix}settings.'),
        if (profile != null) ...profile!._flatten('${prefix}profile.'),
        if (common != null) ...common!._flatten('${prefix}common.'),
        if (screenStates != null)
          ...screenStates!._flatten('${prefix}screenStates.'),
      };

  /// Serializes the dotted slot paths consumed by both native bridges.
  Map<String, String> toMap() => _flatten('');
}

/// Full-color, untinted illustrations shown for empty screens and failed loads.
class OctopusScreenStateIcons {
  /// Illustration on an empty list of posts or comments.
  final OctopusIconSource? emptyContent;

  /// Illustration on an empty list of notifications.
  final OctopusIconSource? emptyNotifications;

  /// Illustration when the first load fails because the device is offline.
  final OctopusIconSource? networkError;

  /// Illustration for other first-load failures.
  final OctopusIconSource? error;

  /// Overrides any screen-state illustration, preserving omitted native defaults.
  const OctopusScreenStateIcons(
      {this.emptyContent,
      this.emptyNotifications,
      this.networkError,
      this.error});

  Map<String, String> _flatten(String prefix) => {
        if (emptyContent != null) '${prefix}emptyContent': emptyContent!.base64,
        if (emptyNotifications != null)
          '${prefix}emptyNotifications': emptyNotifications!.base64,
        if (networkError != null) '${prefix}networkError': networkError!.base64,
        if (error != null) '${prefix}error': error!.base64,
      };
}
