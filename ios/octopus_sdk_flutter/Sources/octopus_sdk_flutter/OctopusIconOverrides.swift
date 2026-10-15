import OctopusUI
import UIKit

/// The native icon set with the host's `theme.icons` overrides applied.
///
/// `images` is keyed by the dotted slot path the Dart layer puts on the wire, with each image already loaded. The
/// paths follow `OctopusTheme.Assets.Icons` one to one. A missing path is passed as `nil`, which
/// keeps the SDK default; an on/off pair is applied only when both of its images loaded, as
/// `OnOff` requires both.
func octopusIcons(from images: [String: UIImage]) -> OctopusUI.OctopusTheme.Assets.Icons {
  typealias Icons = OctopusUI.OctopusTheme.Assets.Icons

  func pair(_ path: String) -> Icons.OnOff? {
    guard let on = images["\(path).on"], let off = images["\(path).off"] else { return nil }
    return Icons.OnOff(on: on, off: off)
  }

  return Icons(
    groups: Icons.Groups(
      openList: images["groups.openList"],
      selected: images["groups.selected"],
      viewGroup: images["groups.viewGroup"]
    ),
    content: Icons.Content(
      post: Icons.Content.Post(
        creation: Icons.Content.Post.Creation(
          open: images["content.post.creation.open"],
          topicSelection: images["content.post.creation.topicSelection"],
          addPicture: images["content.post.creation.addPicture"],
          deletePicture: images["content.post.creation.deletePicture"],
          addPoll: images["content.post.creation.addPoll"],
          addPollOption: images["content.post.creation.addPollOption"],
          deletePoll: images["content.post.creation.deletePoll"],
          deletePollOption: images["content.post.creation.deletePollOption"]
        ),
        emptyFeedInGroups: images["content.post.emptyFeedInGroups"],
        emptyFeedInCurrentUserProfile: images["content.post.emptyFeedInCurrentUserProfile"],
        emptyFeedInOtherUserProfile: images["content.post.emptyFeedInOtherUserProfile"],
        notAvailable: images["content.post.notAvailable"],
        commentCount: images["content.post.commentCount"],
        viewCount: images["content.post.viewCount"],
        moreReactions: images["content.post.moreReactions"],
        likeNotSelected: images["content.post.likeNotSelected"],
        moderated: images["content.post.moderated"]
      ),
      comment: Icons.Content.Comment(
        creation: Icons.Content.Comment.Creation(
          open: images["content.comment.creation.open"],
          create: images["content.comment.creation.create"],
          addPicture: images["content.comment.creation.addPicture"],
          deletePicture: images["content.comment.creation.deletePicture"]
        ),
        emptyFeed: images["content.comment.emptyFeed"],
        notAvailable: images["content.comment.notAvailable"],
        seeReply: images["content.comment.seeReply"],
        likeNotSelected: images["content.comment.likeNotSelected"]
      ),
      reply: Icons.Content.Reply(
        creation: Icons.Content.Reply.Creation(
          open: images["content.reply.creation.open"],
          create: images["content.reply.creation.create"],
          addPicture: images["content.reply.creation.addPicture"],
          deletePicture: images["content.reply.creation.deletePicture"]
        ),
        likeNotSelected: images["content.reply.likeNotSelected"]
      ),
      video: Icons.Content.Video(
        muted: images["content.video.muted"],
        notMuted: images["content.video.notMuted"],
        pause: images["content.video.pause"],
        play: images["content.video.play"],
        replay: images["content.video.replay"]
      ),
      poll: Icons.Content.Poll(
        selectedOption: images["content.poll.selectedOption"]
      ),
      reaction: Icons.Content.Reaction(
        heart: images["content.reaction.heart"],
        joy: images["content.reaction.joy"],
        mouthOpen: images["content.reaction.mouthOpen"],
        clap: images["content.reaction.clap"],
        cry: images["content.reaction.cry"],
        rage: images["content.reaction.rage"]
      ),
      delete: images["content.delete"],
      report: images["content.report"]
    ),
    profile: Icons.Profile(
      addPicture: images["profile.addPicture"],
      editPicture: images["profile.editPicture"],
      addBio: images["profile.addBio"],
      emptyNotifications: images["profile.emptyNotifications"],
      report: images["profile.report"],
      notConnected: images["profile.notConnected"],
      blockUser: images["profile.blockUser"]
    ),
    gamification: Icons.Gamification(
      badge: images["gamification.badge"],
      info: images["gamification.info"],
      rulesHeader: images["gamification.rulesHeader"]
    ),
    settings: Icons.Settings(
      account: images["settings.account"],
      help: images["settings.help"],
      info: images["settings.info"],
      logout: images["settings.logout"],
      deleteAccountWarning: images["settings.deleteAccountWarning"]
    ),
    common: Icons.Common(
      radio: pair("common.radio"),
      checkbox: pair("common.checkbox"),
      toggle: pair("common.toggle"),
      moreActions: images["common.moreActions"],
      activityButton: images["common.activityButton"],
      listCellNavIndicator: images["common.listCellNavIndicator"],
      clearText: images["common.clearText"]
    ),
    screenStates: Icons.ScreenStates(
      emptyContent: images["screenStates.emptyContent"],
      emptyNotifications: images["screenStates.emptyNotifications"],
      networkError: images["screenStates.networkError"],
      error: images["screenStates.error"]
    )
  )
}
