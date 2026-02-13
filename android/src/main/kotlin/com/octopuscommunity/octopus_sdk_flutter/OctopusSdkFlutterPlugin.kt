package com.octopuscommunity.octopus_sdk_flutter

import android.content.Context
import android.graphics.BitmapFactory
import android.util.Base64
import android.util.Log
import com.octopuscommunity.sdk.OctopusSDK
import com.octopuscommunity.sdk.domain.model.ClientUser
import com.octopuscommunity.sdk.domain.model.ConnectionMode
import com.octopuscommunity.sdk.domain.model.Gamification
import com.octopuscommunity.sdk.domain.model.Moderation
import com.octopuscommunity.sdk.domain.model.OctopusEvent
import com.octopuscommunity.sdk.domain.model.OctopusItem
import com.octopuscommunity.sdk.domain.model.ProfileField
import com.octopuscommunity.sdk.domain.model.Resource
import com.octopuscommunity.sdk.domain.model.TrackerEvent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.io.File

/** OctopusSDKFlutterPlugin */
class OctopusSDKFlutterPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    /// The MethodChannel that will make the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context
    private var isOctopusAuthMode: Boolean = false
    private val eventEmitter = OctopusEventEmitter()
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var notSeenNotificationsJob: Job? = null
    private var hasAccessToCommunityJob: Job? = null
    private var eventsJob: Job? = null

    companion object {
        @Volatile
        private var INSTANCE: OctopusSDKFlutterPlugin? = null

        fun getInstance(): OctopusSDKFlutterPlugin? = INSTANCE

        fun triggerCallback(method: String, callbackId: String) {
            Log.d(
                "OctopusSDKFlutterPlugin",
                "triggerCallback called: method=$method, callbackId=$callbackId"
            )
            INSTANCE?.channel?.invokeMethod(method, callbackId)
            Log.d("OctopusSDKFlutterPlugin", "triggerCallback completed")
        }

        fun triggerCallbackWithArgs(method: String, args: Map<String, Any>) {
            Log.d(
                "OctopusSDKFlutterPlugin",
                "triggerCallbackWithArgs called: method=$method, args=$args"
            )
            INSTANCE?.channel?.invokeMethod(method, args)
            Log.d("OctopusSDKFlutterPlugin", "triggerCallbackWithArgs completed")
        }

        fun sendEvent(eventName: String, data: Map<String, Any?>?) {
            Log.d("OctopusSDKFlutterPlugin", "sendEvent called: eventName=$eventName, data=$data")
            OctopusEventEmitter.getInstance()?.sendEvent(eventName, data)
            Log.d("OctopusSDKFlutterPlugin", "sendEvent completed")
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "octopus_sdk_flutter")
        channel.setMethodCallHandler(this)
        eventChannel =
            EventChannel(flutterPluginBinding.binaryMessenger, "octopus_sdk_flutter/events")
        eventChannel.setStreamHandler(this)
        context = flutterPluginBinding.applicationContext
        INSTANCE = this

        // Set up event emitter
        eventEmitter.setMethodChannel(channel)
        OctopusEventEmitter.setInstance(eventEmitter)

        // Register platform view factory for embedded Octopus UI
        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "octopus_sdk_flutter/native_view",
            OctopusEmbeddedView.Factory()
        )
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }

            "initialize" -> {
                initializeOctopusSdk(call, result)
            }

            "initializeOctopusAuth" -> {
                initializeOctopusAuth(call, result)
            }

            "connectUser" -> {
                connectUser(call, result)
            }

            "disconnectUser" -> {
                disconnectUser(result)
            }

            "updateNotSeenNotificationsCount" -> {
                scope.launch {
                    try {
                        OctopusSDK.updateNotSeenNotificationsCount()
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("UPDATE_ERROR", e.message, null)
                    }
                }
            }

            "overrideCommunityAccess" -> {
                val hasAccess = call.argument<Boolean>("hasAccess")
                    ?: return result.error("INVALID_ARGS", "hasAccess is required", null)
                scope.launch {
                    try {
                        OctopusSDK.overrideCommunityAccess(hasAccess)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("OVERRIDE_ERROR", e.message, null)
                    }
                }
            }

            "trackCommunityAccess" -> {
                val hasAccess = call.argument<Boolean>("hasAccess")
                OctopusSDK.trackAccessToCommunity(hasAccess)
                result.success(null)
            }

            "trackCustomEvent" -> {
                val name = call.argument<String>("name")
                    ?: return result.error("INVALID_ARGS", "name is required", null)
                val properties = call.argument<Map<String, String>>("properties") ?: emptyMap()
                scope.launch {
                    try {
                        OctopusSDK.track(
                            TrackerEvent.Custom(
                                name = name,
                                properties = properties.mapValues { TrackerEvent.Custom.Property(it.value) }
                            )
                        )
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("TRACK_ERROR", e.message, null)
                    }
                }
            }

            "overrideDefaultLocale" -> {
                val languageCode = call.argument<String?>("languageCode")
                scope.launch {
                    try {
                        val locale = if (languageCode != null) {
                            val countryCode = call.argument<String?>("countryCode")
                            if (countryCode != null) java.util.Locale(languageCode, countryCode)
                            else java.util.Locale(languageCode)
                        } else null
                        OctopusSDK.overrideDefaultLocale(locale)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("LOCALE_ERROR", e.message, null)
                    }
                }
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    private fun initializeOctopusSdk(call: MethodCall, result: Result) {
        try {
            val apiKey = call.argument<String>("apiKey")
                ?: return result.error("INVALID_ARGS", "apiKey is required", null)

            val appManagedFields = call.argument<List<String>>("appManagedFields") ?: emptyList()

            // Convert app managed fields
            val profileFields = appManagedFields.mapNotNull { fieldName ->
                when (fieldName) {
                    "NICKNAME" -> ProfileField.NICKNAME
                    "PICTURE" -> ProfileField.PICTURE
                    "BIO" -> ProfileField.BIO
                    else -> null
                }
            }.toSet()

            val connectionMode = ConnectionMode.SSO(appManagedFields = profileFields)

            OctopusSDK.initialize(
                context = context,
                apiKey = apiKey,
                connectionMode = connectionMode
            )

            isOctopusAuthMode = false // SSO mode
            startNotSeenNotificationsCollection()
            startHasAccessToCommunityCollection()
            startEventsCollection()
            result.success(null)
        } catch (e: Exception) {
            Log.e("OctopusSdkFlutter", "Error initializing Octopus SDK", e)
            result.error("INITIALIZATION_ERROR", e.message, null)
        }
    }

    private fun initializeOctopusAuth(call: MethodCall, result: Result) {
        try {
            val apiKey = call.argument<String>("apiKey")
                ?: return result.error("INVALID_ARGS", "apiKey is required", null)

            // For Octopus Auth, we don't use connectionMode - it's the default mode
            // The deepLink will be handled automatically by the SDK if configured in the app

            OctopusSDK.initialize(
                context = context,
                apiKey = apiKey
                // No connectionMode = Octopus Auth by default
            )

            isOctopusAuthMode = true // Octopus Auth mode
            startNotSeenNotificationsCollection()
            startHasAccessToCommunityCollection()
            startEventsCollection()
            result.success(null)
        } catch (e: Exception) {
            Log.e("OctopusSdkFlutter", "Error initializing Octopus Auth", e)
            result.error("INITIALIZATION_ERROR", e.message, null)
        }
    }

    private fun connectUser(call: MethodCall, result: Result) {
        // In Octopus Auth mode, connectUser is not needed - authentication is automatic
        if (isOctopusAuthMode) {
            result.error(
                "INVALID_OPERATION",
                "connectUser is not needed in Octopus Auth mode. Authentication is handled automatically by the UI.",
                null
            )
            return
        }

        val userId = call.argument<String>("userId")
            ?: return result.error("INVALID_ARGS", "userId is required", null)

        val token = call.argument<String>("token")
            ?: return result.error("INVALID_ARGS", "token is required", null)

        val nickname = call.argument<String>("nickname")
        val bio = call.argument<String>("bio")
        val picture = call.argument<String>("picture")

        Log.d(
            "OctopusSdkFlutter",
            "ConnectUser - nickname: $nickname, bio: $bio, picture: $picture"
        )

        val clientUser = ClientUser(
            userId = userId,
            profile = ClientUser.Profile(
                nickname = nickname,
                bio = bio,
                picture = toSdkImage(picture)
            )
        )

        scope.launch {
            try {
                OctopusSDK.connectUser(user = clientUser, tokenProvider = { token })
                result.success(null)
            } catch (e: Exception) {
                Log.e("OctopusSdkFlutter", "Error connecting user", e)
                result.error("CONNECT_ERROR", e.message, null)
            }
        }
    }

    private fun disconnectUser(result: Result) {
        scope.launch {
            try {
                OctopusSDK.disconnectUser()
                result.success(null)
            } catch (e: Exception) {
                Log.e("OctopusSdkFlutter", "Error disconnecting user", e)
                result.error("DISCONNECT_ERROR", e.message, null)
            }
        }
    }

    private fun toSdkImage(value: String?): Resource? {
        Log.d("OctopusSdkFlutter", "toSdkImage - input value: $value")
        if (value.isNullOrBlank()) {
            Log.d("OctopusSdkFlutter", "toSdkImage - value is null or blank")
            return null
        }

        return try {
            if (value.startsWith("http")) {
                // It's a URL
                Log.d("OctopusSdkFlutter", "toSdkImage - treating as URL")
                val image = Resource.Remote(url = value)
                Log.d("OctopusSdkFlutter", "toSdkImage - created Remote image: $image")
                image
            } else {
                // It's base64 - decode and save as temp file
                val pure = if (value.startsWith("data:")) {
                    value.substringAfter(",")
                } else {
                    value
                }

                val bytes = Base64.decode(pure, Base64.DEFAULT)
                val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                    ?: return null

                // Create temp file
                val tempFile = File.createTempFile("octopus_image", ".png", context.cacheDir)
                tempFile.outputStream().use { out ->
                    bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, out)
                }

                Log.d(
                    "OctopusSdkFlutter",
                    "toSdkImage - created Local image: ${tempFile.absolutePath}"
                )
                Resource.Local(tempFile.absolutePath)
            }
        } catch (e: Exception) {
            Log.e("OctopusSdkFlutter", "Error converting image", e)
            null
        }
    }


    private fun startNotSeenNotificationsCollection() {
        notSeenNotificationsJob?.cancel()
        notSeenNotificationsJob = scope.launch {
            OctopusSDK.notSeenNotificationsCount.collect { count ->
                sendEvent(
                    "notSeenNotificationsCountChanged",
                    mapOf("count" to count)
                )
            }
        }
    }

    private fun startHasAccessToCommunityCollection() {
        hasAccessToCommunityJob?.cancel()
        hasAccessToCommunityJob = scope.launch {
            OctopusSDK.hasAccessToCommunity.collect { hasAccess ->
                sendEvent(
                    "hasAccessToCommunityChanged",
                    mapOf("hasAccess" to hasAccess)
                )
            }
        }
    }

    private fun startEventsCollection() {
        eventsJob?.cancel()
        eventsJob = scope.launch {
            OctopusSDK.events.collect { event ->
                val data = serializeEvent(event)
                if (data != null) {
                    sendEvent("sdkEvent", data)
                }
            }
        }
    }

    private fun serializeEvent(event: OctopusEvent): Map<String, Any?>? {
        return when (event) {
            is OctopusEvent.PostCreated -> mapOf(
                "type" to "postCreated",
                "postId" to event.postId,
                "content" to event.content.map { content ->
                    when (content) {
                        OctopusEvent.PostCreated.Content.TEXT -> "text"
                        OctopusEvent.PostCreated.Content.IMAGE -> "image"
                        OctopusEvent.PostCreated.Content.POLL -> "poll"
                    }
                },
                "topicId" to event.topicId,
                "textLength" to event.textLength
            )

            is OctopusEvent.CommentCreated -> mapOf(
                "type" to "commentCreated",
                "commentId" to event.commentId,
                "postId" to event.postId,
                "textLength" to event.textLength
            )

            is OctopusEvent.ReplyCreated -> mapOf(
                "type" to "replyCreated",
                "replyId" to event.replyId,
                "commentId" to event.commentId,
                "textLength" to event.textLength
            )

            is OctopusEvent.PostDeleted -> mapOf(
                "type" to "contentDeleted",
                "contentId" to event.contentId,
                "contentKind" to "post"
            )

            is OctopusEvent.CommentDeleted -> mapOf(
                "type" to "contentDeleted",
                "contentId" to event.contentId,
                "contentKind" to "comment"
            )

            is OctopusEvent.ReplyDeleted -> mapOf(
                "type" to "contentDeleted",
                "contentId" to event.contentId,
                "contentKind" to "reply"
            )

            is OctopusEvent.ReactionModified -> mapOf(
                "type" to "reactionModified",
                "contentId" to event.contentId,
                "contentKind" to serializeContentKind(event.contentKind),
                "previousReaction" to event.previousReaction?.let { serializeReactionKind(it) },
                "newReaction" to event.newReaction?.let { serializeReactionKind(it) }
            )

            is OctopusEvent.PollVote -> mapOf(
                "type" to "pollVoted",
                "contentId" to event.contentId,
                "optionId" to event.optionId
            )

            is OctopusEvent.ContentReported -> mapOf(
                "type" to "contentReported",
                "contentId" to event.contentId,
                "reasons" to event.reasons.map { serializeReportReason(it) }
            )

            is OctopusEvent.ProfileReported -> mapOf(
                "type" to "profileReported",
                "profileId" to event.profileId,
                "reasons" to event.reasons.map { serializeReportReason(it) }
            )

            is OctopusEvent.GamificationPointsGained -> mapOf(
                "type" to "gamificationPointsGained",
                "points" to event.points,
                "action" to serializeGamificationAction(event.action)
            )

            is OctopusEvent.GamificationPointsRemoved -> mapOf(
                "type" to "gamificationPointsRemoved",
                "points" to event.points,
                "action" to serializeGamificationAction(event.action)
            )

            is OctopusEvent.ScreenDisplayed -> mapOf(
                "type" to "screenDisplayed",
                "screen" to serializeScreen(event)
            )

            is OctopusEvent.NotificationClicked -> mapOf(
                "type" to "notificationClicked",
                "notificationId" to event.notificationId,
                "contentId" to event.contentId
            )

            is OctopusEvent.PostClicked -> mapOf(
                "type" to "postClicked",
                "postId" to event.postId,
                "source" to when (event.source) {
                    OctopusEvent.PostClicked.Source.FEED -> "feed"
                    OctopusEvent.PostClicked.Source.PROFILE -> "profile"
                }
            )

            is OctopusEvent.TranslationButtonClicked -> mapOf(
                "type" to "translationButtonClicked",
                "contentId" to event.contentId,
                "viewTranslated" to event.viewTranslated,
                "contentKind" to serializeContentKind(event.contentKind)
            )

            is OctopusEvent.CommentButtonClicked -> mapOf(
                "type" to "commentButtonClicked",
                "postId" to event.postId
            )

            is OctopusEvent.ReplyButtonClicked -> mapOf(
                "type" to "replyButtonClicked",
                "commentId" to event.commentId
            )

            is OctopusEvent.SeeRepliesButtonClicked -> mapOf(
                "type" to "seeRepliesButtonClicked",
                "commentId" to event.commentId
            )

            is OctopusEvent.ProfileModified -> {
                val prev = event.previousProfile
                val new = event.newProfile
                val nicknameUpdated = prev?.nickname != new.nickname
                val bioUpdated = prev?.bio != new.bio
                val pictureUpdated = prev?.picture != new.picture
                mapOf(
                    "type" to "profileModified",
                    "nicknameUpdated" to nicknameUpdated,
                    "bioUpdated" to bioUpdated,
                    "bioLength" to if (bioUpdated) new.bio?.length else null,
                    "pictureUpdated" to pictureUpdated,
                    "hasPicture" to if (pictureUpdated) (new.picture != null) else null
                )
            }

            is OctopusEvent.SessionStarted -> mapOf(
                "type" to "sessionStarted",
                "sessionId" to event.sessionId
            )

            is OctopusEvent.SessionStopped -> mapOf(
                "type" to "sessionStopped",
                "sessionId" to event.sessionId
            )
        }
    }

    private fun serializeContentKind(kind: OctopusItem.ContentKind): String {
        return when (kind) {
            OctopusItem.ContentKind.POST -> "post"
            OctopusItem.ContentKind.COMMENT -> "comment"
            OctopusItem.ContentKind.REPLY -> "reply"
        }
    }

    private fun serializeReactionKind(kind: OctopusItem.Reaction.Kind): String {
        return when (kind) {
            is OctopusItem.Reaction.Kind.Heart -> "heart"
            is OctopusItem.Reaction.Kind.Joy -> "joy"
            is OctopusItem.Reaction.Kind.MouthOpen -> "mouthOpen"
            is OctopusItem.Reaction.Kind.Clap -> "clap"
            is OctopusItem.Reaction.Kind.Cry -> "cry"
            is OctopusItem.Reaction.Kind.Rage -> "rage"
            is OctopusItem.Reaction.Kind.Unknown -> "unknown"
        }
    }

    private fun serializeReportReason(reason: Moderation.ReportReason): String {
        return when (reason) {
            is Moderation.ReportReason.HateSpeechOrDiscriminatoryContent -> "hateSpeech"
            is Moderation.ReportReason.ExplicitOrInappropriateContent -> "explicit"
            is Moderation.ReportReason.ViolenceAndTerrorism -> "violence"
            is Moderation.ReportReason.SpamAndScams -> "spam"
            is Moderation.ReportReason.SuicideAndSelfHarm -> "suicide"
            is Moderation.ReportReason.FakeProfilesAndImpersonation -> "fakeProfile"
            is Moderation.ReportReason.ChildExploitationOrAbuse -> "childExploitation"
            is Moderation.ReportReason.IntellectualPropertyViolation -> "intellectualProperty"
            is Moderation.ReportReason.Other -> "other"
        }
    }

    private fun serializeGamificationAction(action: Gamification.Action): String {
        return when (action) {
            Gamification.Action.POST -> "post"
            Gamification.Action.COMMENT -> "comment"
            Gamification.Action.REPLY -> "reply"
            Gamification.Action.REACTION -> "reaction"
            Gamification.Action.VOTE -> "vote"
            Gamification.Action.POST_COMMENTED -> "postCommented"
            Gamification.Action.PROFILE_COMPLETED -> "profileCompleted"
            Gamification.Action.DAILY_SESSION -> "dailySession"
        }
    }

    private fun serializeScreen(event: OctopusEvent.ScreenDisplayed): Map<String, Any?> {
        return when (event) {
            is OctopusEvent.ScreenDisplayed.PostsFeed -> mapOf(
                "type" to "postsFeed",
                "feedId" to event.feedId,
                "relatedTopicId" to event.relatedTopicId
            )
            is OctopusEvent.ScreenDisplayed.PostDetail -> mapOf(
                "type" to "postDetail",
                "postId" to event.postId
            )
            is OctopusEvent.ScreenDisplayed.CommentDetail -> mapOf(
                "type" to "commentDetail",
                "commentId" to event.commentId
            )
            is OctopusEvent.ScreenDisplayed.CreatePost -> mapOf("type" to "createPost")
            is OctopusEvent.ScreenDisplayed.Profile -> mapOf("type" to "profile")
            is OctopusEvent.ScreenDisplayed.OtherUserProfile -> mapOf(
                "type" to "otherUserProfile",
                "profileId" to event.profileId
            )
            is OctopusEvent.ScreenDisplayed.EditProfile -> mapOf("type" to "editProfile")
            is OctopusEvent.ScreenDisplayed.ReportContent -> mapOf("type" to "reportContent")
            is OctopusEvent.ScreenDisplayed.ReportProfile -> mapOf("type" to "reportProfile")
            is OctopusEvent.ScreenDisplayed.ValidateNickname -> mapOf("type" to "validateNickname")
            is OctopusEvent.ScreenDisplayed.SettingsList -> mapOf("type" to "settingsList")
            is OctopusEvent.ScreenDisplayed.SettingsAccount -> mapOf("type" to "settingsAccount")
            is OctopusEvent.ScreenDisplayed.SettingsAbout -> mapOf("type" to "settingsAbout")
            is OctopusEvent.ScreenDisplayed.ReportExplanation -> mapOf("type" to "reportExplanation")
            is OctopusEvent.ScreenDisplayed.DeleteAccount -> mapOf("type" to "deleteAccount")
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        scope.cancel()
        INSTANCE = null
    }

    // EventChannel.StreamHandler implementation
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventEmitter.setEventSink(events)
    }

    override fun onCancel(arguments: Any?) {
        eventEmitter.setEventSink(null)
    }
}
