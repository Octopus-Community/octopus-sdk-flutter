package com.octopuscommunity.octopus_sdk_flutter

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.painter.Painter
import com.octopuscommunity.sdk.ui.OctopusIcons
import com.octopuscommunity.sdk.ui.OctopusIconsDefaults

private fun painterSlot(painter: Painter): @Composable () -> Painter = { painter }

/**
 * The native icon set with the host's `theme.icons` overrides applied.
 *
 * [overrides] is keyed by the iOS dotted slot path the Dart layer puts on the wire, with each image already loaded.
 * Every path is mapped onto its Android field here — the names differ in a few places
 * (`content.post.creation.open` is `post.creation.create`, `content.comment.creation.open`
 * is `post.openCommentCreation`, `content.reply.creation.open` is
 * `comment.openReplyCreation`, `profile.emptyNotifications` lives under `notifications`...).
 * An absent path keeps the SDK default; an on/off pair is applied only when both of its
 * images loaded, as the Dart layer only ever sends complete pairs.
 */
internal fun octopusIconsWithOverrides(overrides: Map<String, Painter>): OctopusIcons {
  val base = OctopusIconsDefaults.icons()
  if (overrides.isEmpty()) return base

  fun slot(path: String, default: @Composable () -> Painter): @Composable () -> Painter =
    overrides[path]?.let(::painterSlot) ?: default

  fun pair(path: String, default: OctopusIcons.OnOff?): OctopusIcons.OnOff? {
    val on = overrides["$path.on"]
    val off = overrides["$path.off"]
    return if (on != null && off != null) {
      OctopusIcons.OnOff(on = painterSlot(on), off = painterSlot(off))
    } else {
      default
    }
  }

  val groups = base.groups
  val content = base.content
  val post = content.post
  val postCreation = post.creation
  val comment = content.comment
  val commentCreation = comment.creation
  val reply = content.reply
  val replyCreation = reply.creation
  val video = content.video
  val reaction = content.reaction
  val gamification = base.gamification
  val settings = base.settings
  val profile = base.profile

  return base.copy(
    groups = groups.copy(
      openList = slot("groups.openList", groups.openList),
      selected = slot("groups.selected", groups.selected),
      viewGroup = slot("groups.viewGroup", groups.viewGroup)
    ),
    content = content.copy(
      post = post.copy(
        creation = postCreation.copy(
          create = slot("content.post.creation.open", postCreation.create),
          topicSelection = slot("content.post.creation.topicSelection", postCreation.topicSelection),
          addPicture = slot("content.post.creation.addPicture", postCreation.addPicture),
          deletePicture = slot("content.post.creation.deletePicture", postCreation.deletePicture),
          addPoll = slot("content.post.creation.addPoll", postCreation.addPoll),
          addPollOption = slot("content.post.creation.addPollOption", postCreation.addPollOption),
          deletePoll = slot("content.post.creation.deletePoll", postCreation.deletePoll),
          deletePollOption = slot("content.post.creation.deletePollOption", postCreation.deletePollOption)
        ),
        emptyFeedInGroups = slot("content.post.emptyFeedInGroups", post.emptyFeedInGroups),
        emptyFeedInCurrentUserProfile =
          slot("content.post.emptyFeedInCurrentUserProfile", post.emptyFeedInCurrentUserProfile),
        emptyFeedInOtherUserProfile =
          slot("content.post.emptyFeedInOtherUserProfile", post.emptyFeedInOtherUserProfile),
        notAvailable = slot("content.post.notAvailable", post.notAvailable),
        moderated = slot("content.post.moderated", post.moderated),
        commentCount = slot("content.post.commentCount", post.commentCount),
        openCommentCreation = slot("content.comment.creation.open", post.openCommentCreation),
        views = slot("content.post.viewCount", post.views),
        likeNotSelected = slot("content.post.likeNotSelected", post.likeNotSelected),
        moreReactions = slot("content.post.moreReactions", post.moreReactions)
      ),
      comment = comment.copy(
        creation = commentCreation.copy(
          create = slot("content.comment.creation.create", commentCreation.create),
          addPicture = slot("content.comment.creation.addPicture", commentCreation.addPicture),
          deletePicture = slot("content.comment.creation.deletePicture", commentCreation.deletePicture)
        ),
        emptyFeed = slot("content.comment.emptyFeed", comment.emptyFeed),
        notAvailable = slot("content.comment.notAvailable", comment.notAvailable),
        openReplyCreation = slot("content.reply.creation.open", comment.openReplyCreation),
        seeReplies = slot("content.comment.seeReply", comment.seeReplies),
        likeNotSelected = slot("content.comment.likeNotSelected", comment.likeNotSelected)
      ),
      reply = reply.copy(
        creation = replyCreation.copy(
          create = slot("content.reply.creation.create", replyCreation.create),
          addPicture = slot("content.reply.creation.addPicture", replyCreation.addPicture),
          deletePicture = slot("content.reply.creation.deletePicture", replyCreation.deletePicture)
        ),
        likeNotSelected = slot("content.reply.likeNotSelected", reply.likeNotSelected)
      ),
      video = video.copy(
        muted = slot("content.video.muted", video.muted),
        notMuted = slot("content.video.notMuted", video.notMuted),
        pause = slot("content.video.pause", video.pause),
        play = slot("content.video.play", video.play),
        replay = slot("content.video.replay", video.replay)
      ),
      poll = content.poll.copy(
        selectedOption = slot("content.poll.selectedOption", content.poll.selectedOption)
      ),
      reaction = reaction.copy(
        heart = slot("content.reaction.heart", reaction.heart),
        joy = slot("content.reaction.joy", reaction.joy),
        mouthOpen = slot("content.reaction.mouthOpen", reaction.mouthOpen),
        clap = slot("content.reaction.clap", reaction.clap),
        cry = slot("content.reaction.cry", reaction.cry),
        rage = slot("content.reaction.rage", reaction.rage)
      ),
      delete = slot("content.delete", content.delete),
      report = slot("content.report", content.report)
    ),
    gamification = gamification.copy(
      badge = slot("gamification.badge", gamification.badge),
      info = slot("gamification.info", gamification.info),
      rulesHeader = slot("gamification.rulesHeader", gamification.rulesHeader)
    ),
    settings = settings.copy(
      account = slot("settings.account", settings.account),
      help = slot("settings.help", settings.help),
      info = slot("settings.info", settings.info),
      logout = slot("settings.logout", settings.logout),
      deleteAccountWarning = slot("settings.deleteAccountWarning", settings.deleteAccountWarning)
    ),
    profile = profile.copy(
      addPicture = slot("profile.addPicture", profile.addPicture),
      editPicture = slot("profile.editPicture", profile.editPicture),
      addBio = slot("profile.addBio", profile.addBio),
      report = slot("profile.report", profile.report),
      notConnected = slot("profile.notConnected", profile.notConnected),
      blockUser = slot("profile.blockUser", profile.blockUser)
    ),
    notifications = base.notifications.copy(
      emptyNotifications = slot("profile.emptyNotifications", base.notifications.emptyNotifications)
    ),
    screenStates = OctopusIconsDefaults.screenStates(
      emptyContent = slot("screenStates.emptyContent", base.screenStates.emptyContent),
      emptyNotifications = slot("screenStates.emptyNotifications", base.screenStates.emptyNotifications),
      networkError = slot("screenStates.networkError", base.screenStates.networkError),
      error = slot("screenStates.error", base.screenStates.error)
    ),
    radio = pair("common.radio", base.radio),
    checkbox = pair("common.checkbox", base.checkbox),
    toggle = pair("common.toggle", base.toggle),
    moreActions = slot("common.moreActions", base.moreActions),
    activityButton = slot("common.activityButton", base.activityButton),
    cellNavIndicator = slot("common.listCellNavIndicator", base.cellNavIndicator)
  )
}

internal fun parseIconSources(value: Any?): Map<String, String> =
    (value as? Map<*, *>)?.entries?.mapNotNull { (key, value) ->
        if (key is String && value is String) key to value else null
    }?.toMap() ?: emptyMap()
