package com.octopuscommunity.octopus_sdk_flutter

import android.content.Context
import android.graphics.BitmapFactory
import android.util.Base64
import android.util.Log
import com.octopuscommunity.sdk.ApiServer
import com.octopuscommunity.sdk.OctopusSDK
import com.octopuscommunity.sdk.domain.model.ClientPost
import com.octopuscommunity.sdk.domain.model.ClientUser
import com.octopuscommunity.sdk.domain.model.ConnectionMode
import com.octopuscommunity.sdk.domain.model.Gamification
import com.octopuscommunity.sdk.domain.model.Moderation
import com.octopuscommunity.sdk.domain.model.OctopusEvent
import com.octopuscommunity.sdk.domain.model.OctopusCommunityData
import com.octopuscommunity.sdk.domain.model.OctopusItem
import com.octopuscommunity.sdk.domain.model.OctopusPost
import com.octopuscommunity.sdk.domain.model.OctopusReactionKind
import com.octopuscommunity.sdk.domain.model.ProfileField
import com.octopuscommunity.sdk.domain.model.Resource
import com.octopuscommunity.sdk.domain.model.SyncFollowGroupAction
import com.octopuscommunity.sdk.domain.model.SyncFollowGroupStatus
import com.octopuscommunity.sdk.domain.repository.ConnectionRepository.ConnectionState
import com.octopuscommunity.sdk.domain.model.TrackerEvent
import com.octopuscommunity.sdk.domain.network.OctopusResult
import com.octopuscommunity.sdk.domain.network.ServerError
import com.octopuscommunity.sdk.domain.model.OctopusGroup
import com.octopuscommunity.sdk.domain.repository.ClientPostError
import com.octopuscommunity.sdk.domain.repository.ClientUserError
import com.octopuscommunity.sdk.domain.repository.CommunityConfigRepository.OverrideCommunityAccessError
import com.octopuscommunity.sdk.domain.repository.GroupFollowUnfollowError
import com.octopuscommunity.sdk.domain.repository.RefreshEntitlementsError
import com.octopuscommunity.sdk.domain.repository.SetReactionError
import java.util.Date
import java.util.concurrent.atomic.AtomicLong
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.File
import java.util.concurrent.ConcurrentHashMap

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
    // Sink this plugin instance handed to [OctopusEventEmitter] in [onListen],
    // remembered so [onCancel] can compare-and-clear without wiping a sink
    // that belongs to another FlutterEngine.
    private var listeningSink: EventChannel.EventSink? = null
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var notSeenNotificationsJob: Job? = null
    private var hasAccessToCommunityJob: Job? = null
    private var profileJob: Job? = null
    private var groupsJob: Job? = null
    private var connectionStateJob: Job? = null
    private var eventsJob: Job? = null
    private var isInitialisedJob: Job? = null

    // Pending client-user-token requests, keyed by the in-flight requestId. The
    // persistent connectUser tokenProvider lambda registered via
    // `connectUserWithTokenProvider` parks a CompletableDeferred here and
    // awaits it; the Dart `provideClientUserToken` reply completes it. The
    // native SDK calls the lambda initially and on every subsequent refresh
    // (e.g. `refreshEntitlements()`), so each invocation gets a fresh
    // requestId and parks its own deferred — concurrent refreshes won't race.
    private val clientUserTokenDeferreds = ConcurrentHashMap<String, CompletableDeferred<String>>()
    private val clientUserTokenRequestCounter = AtomicLong(0)

    // Active client-object-post observation jobs, keyed by the Dart-supplied
    // observationId (one per getClientObjectRelatedPostFlow subscription).
    private val clientObjectPostJobs = ConcurrentHashMap<String, Job>()
    private val communityDataJobs = ConcurrentHashMap<String, Job>()

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
            // Route through the process-static [OctopusEventEmitter] singleton.
            // Do NOT look up a plugin/emitter `INSTANCE` reference: a secondary
            // FlutterEngine attaching this plugin (e.g. firebase_messaging's
            // headless engine) would overwrite that reference with an emitter
            // whose sink is never set, silently dropping every event sent to
            // the foreground Dart isolate.
            OctopusEventEmitter.sendEvent(eventName, data)
            Log.d("OctopusSDKFlutterPlugin", "sendEvent completed")
        }

        // Pending bridge-token requests, keyed by the in-flight requestId.
        // PROCESS-STATIC (not per-instance) so a separately-launched
        // [OctopusCreatePostActivity] — which holds no plugin reference — and a
        // secondary FlutterEngine share the same in-flight set, the same
        // reasoning as the process-static event emitter above. The suspend
        // provider parks a CompletableDeferred here and awaits it; the Dart
        // `provideBridgeToken` reply completes it. Concurrent: the requestId
        // scopes each request, and the lambda may run off the main thread while
        // the reply arrives on it.
        internal val bridgeTokenDeferreds =
            ConcurrentHashMap<String, CompletableDeferred<String?>>()

        /**
         * Runs the native→Dart bridge-token round-trip for [requestId]: parks a
         * deferred, emits a `bridgeTokenRequest` event carrying [fingerprint],
         * and awaits the matching `provideBridgeToken` reply (the host returns
         * `null` when no signature is needed). Shared by
         * [fetchOrCreateClientObjectRelatedPost] and the create-post editor's
         * bridge-share signer ([OctopusCreatePostActivity]).
         */
        internal suspend fun requestBridgeToken(
            requestId: String,
            fingerprint: String
        ): String? {
            val deferred = CompletableDeferred<String?>()
            bridgeTokenDeferreds[requestId] = deferred
            return try {
                // The event sink must be touched on the main thread.
                withContext(Dispatchers.Main) {
                    sendEvent(
                        "bridgeTokenRequest",
                        mapOf("requestId" to requestId, "fingerprint" to fingerprint)
                    )
                }
                deferred.await()
            } finally {
                bridgeTokenDeferreds.remove(requestId)
            }
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

        // No emitter wiring here: [OctopusEventEmitter] is a process-static
        // singleton; the foreground engine claims dispatch by setting its
        // sink in [onListen]. See the OctopusEventEmitter class comment.

        // Register platform view factory for embedded Octopus UI
        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "octopus_sdk_flutter/native_view",
            OctopusEmbeddedView.Factory()
        )

        // Track the SDK init state from attach (it is process-static and
        // exists before initialize), so isInitialisedFlow reflects pre-init
        // and stop() transitions.
        startIsInitialisedCollection()

        // Register the SDK-level group-access-denied callback once (it is a
        // process-static field). The embedded view's octopusComposables(...)
        // passes no per-screen onGroupAccessDenied, so this SDK-level callback
        // is the one invoked. Forwarded to Dart via the event channel; the Dart
        // consumer opts in via OctopusSDK.setGroupAccessDeniedCallback.
        OctopusSDK.setGroupAccessDeniedCallback { groupId ->
            sendEvent("groupAccessDenied", mapOf("groupId" to groupId))
        }
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

            "switchCommunity" -> {
                switchCommunity(call, result)
            }

            "switchCommunityOctopusAuth" -> {
                switchCommunityOctopusAuth(call, result)
            }

            "reset" -> {
                reset(result)
            }

            "stop" -> {
                stop(result)
            }

            "connectUser" -> {
                connectUser(call, result)
            }

            "connectUserWithTokenProvider" -> {
                connectUserWithTokenProvider(call, result)
            }

            "provideClientUserToken" -> {
                provideClientUserToken(call, result)
            }

            "disconnectUser" -> {
                disconnectUser(result)
            }

            "showCreatePostScreen" -> {
                showCreatePostScreen(call, result)
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
                        val res = OctopusSDK.overrideCommunityAccess(hasAccess)
                        result.success(
                            encodeOctopusResult(res) { e ->
                                when (e) {
                                    is OverrideCommunityAccessError.Unknown ->
                                        mapOf("type" to "unknown", "message" to e.errorMessage)
                                }
                            }
                        )
                    } catch (e: Exception) {
                        result.error("OVERRIDE_ERROR", e.message, null)
                    }
                }
            }

            "refreshEntitlements" -> {
                scope.launch {
                    try {
                        val res = OctopusSDK.refreshEntitlements()
                        result.success(
                            encodeOctopusResult(res) { e ->
                                when (e) {
                                    is RefreshEntitlementsError.NoClientTokenProvider ->
                                        mapOf("type" to "noClientTokenProvider", "message" to e.errorMessage)
                                    is RefreshEntitlementsError.UserNotConnected ->
                                        mapOf("type" to "userNotConnected", "message" to e.errorMessage)
                                    is RefreshEntitlementsError.NoNetwork ->
                                        mapOf("type" to "noNetwork", "message" to e.errorMessage)
                                    is RefreshEntitlementsError.UserBanned ->
                                        mapOf("type" to "userBanned", "message" to e.errorMessage)
                                    is RefreshEntitlementsError.ServerError ->
                                        mapOf("type" to "serverError", "message" to e.errorMessage)
                                }
                            }
                        )
                    } catch (e: Exception) {
                        result.error("REFRESH_ENTITLEMENTS_ERROR", e.message, null)
                    }
                }
            }

            "setReaction" -> {
                val postId = call.argument<String>("postId")
                    ?: return result.error("INVALID_ARGS", "postId is required", null)
                val reaction = deserializeReactionKind(call.argument<Map<String, Any?>>("reaction"))
                scope.launch {
                    try {
                        val res = OctopusSDK.setReaction(reaction = reaction, postId = postId)
                        result.success(
                            encodeOctopusResult(res) { e ->
                                when (e) {
                                    is SetReactionError.UnknownReaction ->
                                        mapOf("type" to "unknownReaction", "message" to e.errorMessage)
                                    is SetReactionError.PostNotFound ->
                                        mapOf("type" to "postNotFound", "message" to e.errorMessage)
                                    is SetReactionError.ReactionError ->
                                        mapOf("type" to "reactionError", "message" to e.errorMessage)
                                }
                            }
                        )
                    } catch (e: Exception) {
                        result.error("SET_REACTION_ERROR", e.message, null)
                    }
                }
            }

            "fetchOrCreateClientObjectRelatedPost" -> {
                fetchOrCreateClientObjectRelatedPost(call, result)
            }

            "provideBridgeToken" -> {
                val requestId = call.argument<String>("requestId")
                    ?: return result.error("INVALID_ARGS", "requestId is required", null)
                val token = call.argument<String?>("token")
                // Complete the parked request (the lambda's finally removes it).
                bridgeTokenDeferreds[requestId]?.complete(token)
                result.success(null)
            }

            "startClientObjectPostObservation" -> {
                val observationId = call.argument<String>("observationId")
                    ?: return result.error("INVALID_ARGS", "observationId is required", null)
                val clientObjectId = call.argument<String>("clientObjectId")
                    ?: return result.error("INVALID_ARGS", "clientObjectId is required", null)
                // Match the iOS guard: reject before initialize() rather than
                // silently collecting the SDK's uninitialized fallback container.
                if (!OctopusSDK.isInitialised) {
                    return result.error("NOT_INITIALIZED", "Call initialize() first", null)
                }
                startClientObjectPostObservation(observationId, clientObjectId)
                result.success(null)
            }

            "stopClientObjectPostObservation" -> {
                val observationId = call.argument<String>("observationId")
                    ?: return result.error("INVALID_ARGS", "observationId is required", null)
                clientObjectPostJobs.remove(observationId)?.cancel()
                result.success(null)
            }

            "fetchCommunityData" -> {
                val profileId = call.argument<String>("profileId")
                val clientUserId = call.argument<String>("clientUserId")
                if ((profileId == null) == (clientUserId == null)) {
                    return result.error(
                        "INVALID_ARGS",
                        "exactly one of profileId or clientUserId is required",
                        null
                    )
                }
                if (!OctopusSDK.isInitialised) {
                    return result.error("NOT_INITIALIZED", "Call initialize() first", null)
                }
                scope.launch {
                    try {
                        // Android names the Octopus id `userId`; the wrapper calls it
                        // `profileId` throughout (matching iOS + the screen events).
                        val data = if (profileId != null) {
                            OctopusSDK.fetchCommunityData(profileId)
                        } else {
                            OctopusSDK.fetchCommunityDataByClientUserId(clientUserId!!)
                        }
                        result.success(data?.let { serializeCommunityData(it) })
                    } catch (e: Exception) {
                        Log.e("OctopusSdkFlutter", "fetchCommunityData failed", e)
                        result.error("FETCH_FAILED", e.message, null)
                    }
                }
            }

            "startCommunityDataObservation" -> {
                val observationId = call.argument<String>("observationId")
                    ?: return result.error("INVALID_ARGS", "observationId is required", null)
                val profileId = call.argument<String>("profileId")
                val clientUserId = call.argument<String>("clientUserId")
                if ((profileId == null) == (clientUserId == null)) {
                    return result.error(
                        "INVALID_ARGS",
                        "exactly one of profileId or clientUserId is required",
                        null
                    )
                }
                if (!OctopusSDK.isInitialised) {
                    return result.error("NOT_INITIALIZED", "Call initialize() first", null)
                }
                startCommunityDataObservation(observationId, profileId, clientUserId)
                result.success(null)
            }

            "stopCommunityDataObservation" -> {
                val observationId = call.argument<String>("observationId")
                    ?: return result.error("INVALID_ARGS", "observationId is required", null)
                communityDataJobs.remove(observationId)?.cancel()
                result.success(null)
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

            "registerPushNotificationToken" -> {
                val token = call.argument<String>("token")
                    ?: return result.error("INVALID_ARGS", "token is required", null)
                OctopusSDK.registerNotificationsToken(fcmRegistrationToken = token)
                result.success(null)
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

            "fetchGroups" -> {
                scope.launch {
                    try {
                        val res = OctopusSDK.fetchGroups()
                        result.success(encodeGroupListResult(res))
                    } catch (e: Exception) {
                        result.error("FETCH_GROUPS_ERROR", e.message, null)
                    }
                }
            }

            "followGroup" -> {
                val groupId = call.argument<String>("groupId")
                    ?: return result.error("INVALID_ARGS", "groupId is required", null)
                scope.launch {
                    try {
                        val res = OctopusSDK.followGroup(groupId)
                        result.success(
                            encodeOctopusResult(res) { e -> encodeGroupFollowUnfollowError(e) }
                        )
                    } catch (e: Exception) {
                        result.error("FOLLOW_GROUP_ERROR", e.message, null)
                    }
                }
            }

            "unfollowGroup" -> {
                val groupId = call.argument<String>("groupId")
                    ?: return result.error("INVALID_ARGS", "groupId is required", null)
                scope.launch {
                    try {
                        val res = OctopusSDK.unfollowGroup(groupId)
                        result.success(
                            encodeOctopusResult(res) { e -> encodeGroupFollowUnfollowError(e) }
                        )
                    } catch (e: Exception) {
                        result.error("UNFOLLOW_GROUP_ERROR", e.message, null)
                    }
                }
            }

            "syncFollowGroups" -> {
                @Suppress("UNCHECKED_CAST")
                val rawActions =
                    call.argument<List<Map<String, Any>>>("actions") ?: emptyList()
                if (rawActions.isEmpty()) {
                    result.success(emptyList<Map<String, Any>>())
                    return
                }
                val actions = rawActions.map { m ->
                    SyncFollowGroupAction(
                        groupId = m["groupId"] as String,
                        followed = m["followed"] as Boolean,
                        actionDate = Date((m["actionDateMs"] as Number).toLong())
                    )
                }
                scope.launch {
                    try {
                        when (val res = OctopusSDK.syncFollowGroups(actions)) {
                            is OctopusResult.Success -> {
                                val payload = res.data.map { r ->
                                    mapOf(
                                        "groupId" to r.groupId,
                                        "status" to r.status.toWireValue()
                                    )
                                }
                                result.success(payload)
                            }
                            is OctopusResult.Failure -> {
                                val (code, message) = when (res) {
                                    is OctopusResult.Failure.NoNetwork ->
                                        "no_network" to "No network"
                                    is OctopusResult.Failure.UserNotAuthenticated ->
                                        "not_connected" to (res.reason ?: "User not authenticated")
                                    is OctopusResult.Failure.PermissionDenied ->
                                        "not_connected" to (res.reason ?: "Permission denied")
                                    is OctopusResult.Failure.StatusError ->
                                        "server" to (res.description ?: "Server error ${res.code}")
                                    is OctopusResult.Failure.ContentUnavailable ->
                                        "other" to "Content unavailable"
                                    else -> "other" to res.toString()
                                }
                                result.error(code, message, null)
                            }
                        }
                    } catch (e: Exception) {
                        result.error("other", e.message, null)
                    }
                }
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    /// Parses the optional `apiServer` argument into a native [ApiServer], or
    /// returns null when absent. The [ApiServer] constructor validates the host
    /// and throws on malformed input (caught by the caller's try/catch).
    private fun parseApiServer(call: MethodCall): ApiServer? {
        val map = call.argument<Map<String, Any>>("apiServer") ?: return null
        val host = map["host"] as? String ?: return null
        val port = (map["port"] as? Number)?.toInt() ?: 443
        return ApiServer(host = host, port = port)
    }

    /// Converts the optional `appManagedFields` wire strings into native
    /// [ProfileField]s. Unrecognized strings are logged loudly so a future
    /// Dart-side rename does not silently turn into "Octopus manages this
    /// field" (the AVATAR/PICTURE bug that hid here pre-1.11.0).
    private fun parseAppManagedFields(call: MethodCall): Set<ProfileField> {
        val appManagedFields = call.argument<List<String>>("appManagedFields") ?: emptyList()
        return appManagedFields.mapNotNull { fieldName ->
            when (fieldName) {
                "NICKNAME" -> ProfileField.NICKNAME
                "PICTURE" -> ProfileField.PICTURE
                "BIO" -> ProfileField.BIO
                else -> {
                    Log.w(
                        "OctopusSDKFlutterPlugin",
                        "Unknown appManagedFields entry '$fieldName' — dropped. " +
                            "Expected one of NICKNAME, PICTURE, BIO."
                    )
                    null
                }
            }
        }.toSet()
    }

    private fun initializeOctopusSdk(call: MethodCall, result: Result) {
        try {
            val apiKey = call.argument<String>("apiKey")
                ?: return result.error("INVALID_ARGS", "apiKey is required", null)

            val connectionMode = ConnectionMode.SSO(appManagedFields = parseAppManagedFields(call))

            OctopusSDK.initialize(
                context = context,
                apiKey = apiKey,
                connectionMode = connectionMode,
                apiServer = parseApiServer(call)
            )

            isOctopusAuthMode = false // SSO mode
            startNotSeenNotificationsCollection()
            startHasAccessToCommunityCollection()
            startProfileCollection()
            startGroupsCollection()
            startConnectionStateCollection()
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
                apiKey = apiKey,
                // No connectionMode = Octopus Auth by default
                apiServer = parseApiServer(call)
            )

            isOctopusAuthMode = true // Octopus Auth mode
            startNotSeenNotificationsCollection()
            startHasAccessToCommunityCollection()
            startProfileCollection()
            startGroupsCollection()
            startConnectionStateCollection()
            startEventsCollection()
            result.success(null)
        } catch (e: Exception) {
            Log.e("OctopusSdkFlutter", "Error initializing Octopus Auth", e)
            result.error("INITIALIZATION_ERROR", e.message, null)
        }
    }

    /// Switches to a different community in SSO mode. Mirrors
    /// [initializeOctopusSdk]; [OctopusSDK.switchCommunity] resets the current
    /// instance (disconnect + clear cached data) before reinitializing.
    private fun switchCommunity(call: MethodCall, result: Result) {
        val apiKey = call.argument<String>("apiKey")
            ?: return result.error("INVALID_ARGS", "apiKey is required", null)

        val connectionMode = ConnectionMode.SSO(appManagedFields = parseAppManagedFields(call))
        val apiServer = try {
            parseApiServer(call)
        } catch (e: Exception) {
            return result.error("SWITCH_COMMUNITY_ERROR", e.message, null)
        }

        scope.launch {
            try {
                OctopusSDK.switchCommunity(
                    context = context,
                    apiKey = apiKey,
                    connectionMode = connectionMode,
                    apiServer = apiServer
                )
                isOctopusAuthMode = false // SSO mode
                startNotSeenNotificationsCollection()
                startHasAccessToCommunityCollection()
                startProfileCollection()
                startGroupsCollection()
                startConnectionStateCollection()
                startEventsCollection()
                result.success(null)
            } catch (e: Exception) {
                Log.e("OctopusSdkFlutter", "Error switching community", e)
                result.error("SWITCH_COMMUNITY_ERROR", e.message, null)
            }
        }
    }

    /// Switches to a different community in Octopus Auth mode. Mirrors
    /// [initializeOctopusAuth] (no explicit connectionMode).
    private fun switchCommunityOctopusAuth(call: MethodCall, result: Result) {
        val apiKey = call.argument<String>("apiKey")
            ?: return result.error("INVALID_ARGS", "apiKey is required", null)

        val apiServer = try {
            parseApiServer(call)
        } catch (e: Exception) {
            return result.error("SWITCH_COMMUNITY_ERROR", e.message, null)
        }

        scope.launch {
            try {
                OctopusSDK.switchCommunity(
                    context = context,
                    apiKey = apiKey,
                    // No connectionMode = Octopus Auth by default
                    apiServer = apiServer
                )
                isOctopusAuthMode = true // Octopus Auth mode
                startNotSeenNotificationsCollection()
                startHasAccessToCommunityCollection()
                startProfileCollection()
                startGroupsCollection()
                startConnectionStateCollection()
                startEventsCollection()
                result.success(null)
            } catch (e: Exception) {
                Log.e("OctopusSdkFlutter", "Error switching community (Octopus Auth)", e)
                result.error("SWITCH_COMMUNITY_ERROR", e.message, null)
            }
        }
    }

    /// Disconnects the user and clears cached data; the SDK stays initialized.
    private fun reset(result: Result) {
        scope.launch {
            try {
                OctopusSDK.reset()
                result.success(null)
            } catch (e: Exception) {
                Log.e("OctopusSdkFlutter", "Error resetting Octopus SDK", e)
                result.error("RESET_ERROR", e.message, null)
            }
        }
    }

    /// Stops the SDK and releases resources; the SDK becomes uninitialized.
    private fun stop(result: Result) {
        try {
            notSeenNotificationsJob?.cancel()
            hasAccessToCommunityJob?.cancel()
            profileJob?.cancel()
            groupsJob?.cancel()
            connectionStateJob?.cancel()
            eventsJob?.cancel()
            clientObjectPostJobs.values.forEach { it.cancel() }
            clientObjectPostJobs.clear()
            communityDataJobs.values.forEach { it.cancel() }
            communityDataJobs.clear()
            OctopusSDK.stop()
            result.success(null)
        } catch (e: Exception) {
            Log.e("OctopusSdkFlutter", "Error stopping Octopus SDK", e)
            result.error("STOP_ERROR", e.message, null)
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
                // The native SDK REPORTS a refusal (banned user, rejected JWT,
                // missing token) in its OctopusResult — it does not throw.
                // Dropping it would report success while the user stays
                // anonymous, so forward it to Dart.
                val connectResult =
                    OctopusSDK.connectUser(user = clientUser, tokenProvider = { token })
                result.success(encodeOctopusResult(connectResult, ::encodeClientUserError))
            } catch (e: Exception) {
                Log.e("OctopusSdkFlutter", "Error connecting user", e)
                result.error("CONNECT_ERROR", e.message, null)
            }
        }
    }

    /// Persistent tokenProvider path — mirrors iOS's
    /// `connectUserWithTokenProvider`. The lambda is invoked initially (on
    /// connect) AND on every refresh (e.g. `refreshEntitlements()` minting a
    /// fresh JWT with the host's current entitlement set), so the lambda
    /// must round-trip back to Dart on every invocation — not capture a
    /// static token. The Dart side keys its provider on `providerId`, the
    /// requestId scopes one invocation.
    private fun connectUserWithTokenProvider(call: MethodCall, result: Result) {
        if (isOctopusAuthMode) {
            result.error(
                "INVALID_OPERATION",
                "connectUserWithTokenProvider is not needed in Octopus Auth mode.",
                null
            )
            return
        }
        if (!OctopusSDK.isInitialised) {
            result.error("NOT_INITIALIZED", "Call initialize() first", null)
            return
        }
        val userId = call.argument<String>("userId")
            ?: return result.error("INVALID_ARGS", "userId is required", null)
        val providerId = call.argument<String>("providerId")
            ?: return result.error("INVALID_ARGS", "providerId is required", null)
        val nickname = call.argument<String>("nickname")
        val bio = call.argument<String>("bio")
        val picture = call.argument<String>("picture")
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
                val connectResult = OctopusSDK.connectUser(
                    user = clientUser,
                    tokenProvider = {
                        val requestId =
                            "clientUserToken_${clientUserTokenRequestCounter.incrementAndGet()}"
                        val deferred = CompletableDeferred<String>()
                        clientUserTokenDeferreds[requestId] = deferred
                        try {
                            sendEvent(
                                "clientUserTokenRequest",
                                mapOf(
                                    "providerId" to providerId,
                                    "requestId" to requestId,
                                )
                            )
                            // Bound the round-trip: a Dart side that never
                            // replies (host bug, provider hanging on a dead
                            // network call) would otherwise park this
                            // coroutine forever, and with it the caller's
                            // Future. This native SDK refuses an empty token
                            // locally, as ClientUserError.MissingToken, so a
                            // timeout surfaces through the normal typed path.
                            withTimeoutOrNull(CLIENT_USER_TOKEN_TIMEOUT_MS) {
                                deferred.await()
                            } ?: run {
                                Log.w(
                                    "OctopusSdkFlutter",
                                    "Client user token request $requestId timed out"
                                )
                                ""
                            }
                        } finally {
                            clientUserTokenDeferreds.remove(requestId)
                        }
                    }
                )
                result.success(encodeOctopusResult(connectResult, ::encodeClientUserError))
            } catch (e: Exception) {
                Log.e("OctopusSdkFlutter", "Error connecting user with tokenProvider", e)
                result.error("CONNECT_ERROR", e.message, null)
            }
        }
    }

    /// Resumes the parked client-user-token request with the freshly-signed
    /// JWT (or an empty string when the Dart side couldn't sign — this native
    /// SDK refuses an empty token locally, as `ClientUserError.MissingToken`).
    private fun provideClientUserToken(call: MethodCall, result: Result) {
        val requestId = call.argument<String>("requestId")
            ?: return result.error("INVALID_ARGS", "requestId is required", null)
        val token = call.argument<String>("token") ?: ""
        clientUserTokenDeferreds[requestId]?.complete(token)
        result.success(null)
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

    /**
     * Launches the native [OctopusCreatePostActivity] full-screen — the editor
     * runs in a real activity destination (its own nav bar, X button, group
     * picker, publish flow), then `finish()`s, at which point this method's
     * `Result.success(null)` completes the Dart-side `Future`.
     *
     * The Dart side passes the same map shape that previously flew through the
     * create-post PlatformView creationParams (`prefilledPost`, theme, fonts).
     */
    private fun showCreatePostScreen(call: MethodCall, result: Result) {
        @Suppress("UNCHECKED_CAST")
        val args = call.arguments as? Map<String, Any?>
        try {
            val intent = OctopusCreatePostActivity.newIntent(context, args)
            context.startActivity(intent)
            // We don't observe the activity's actual finish here (no
            // ActivityResultLauncher available to a plugin without a host
            // ActivityAware hook). The future resolves when the call returns —
            // the editor close is observed by the host via the existing
            // `loginRequired`/`editUser`/`navigateToClientObject` events the
            // activity emits before finishing on those paths, or simply by the
            // user dismissing the editor. Adding `ActivityAware` for a strict
            // dismissed-result would be a follow-up.
            result.success(null)
        } catch (e: Exception) {
            Log.e("OctopusSdkFlutter", "Error showing create-post screen", e)
            result.error("CREATE_POST_ERROR", e.message, null)
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

    // region Bridge (client object related post)

    /// Fetches (or creates) the Octopus post linked to a client object. When
    /// [hasTokenProvider] is true, the SDK's `tokenProvider` callback is wired to
    /// the Dart side over the event channel: the lambda fires a
    /// `bridgeTokenRequest` event with [requestId] and the bridge fingerprint,
    /// then awaits the matching `provideBridgeToken` reply (explicit null-reply
    /// contract). The result is encoded with the shared OctopusResult wire,
    /// carrying the serialized post on success.
    private fun fetchOrCreateClientObjectRelatedPost(call: MethodCall, result: Result) {
        val clientPostMap = call.argument<Map<String, Any?>>("clientPost")
            ?: return result.error("INVALID_ARGS", "clientPost is required", null)
        val requestId = call.argument<String>("requestId")
            ?: return result.error("INVALID_ARGS", "requestId is required", null)
        val hasTokenProvider = call.argument<Boolean>("hasTokenProvider") ?: false

        val clientPost = try {
            decodeClientPost(clientPostMap)
        } catch (e: Exception) {
            return result.error("INVALID_ARGS", "Invalid clientPost: ${e.message}", null)
        }

        val tokenProvider: (suspend (String) -> String?)? = if (hasTokenProvider) {
            { fingerprint -> requestBridgeToken(requestId, fingerprint) }
        } else null

        scope.launch {
            try {
                val res = OctopusSDK.fetchOrCreateClientObjectRelatedPost(clientPost, tokenProvider)
                result.success(encodeOctopusPostResult(res))
            } catch (e: Exception) {
                result.error("FETCH_OR_CREATE_ERROR", e.message, null)
            }
        }
    }

    /// Collects [OctopusSDK.getClientObjectRelatedPostFlow] for [clientObjectId]
    /// and forwards each emission (the post, or `null`) as a
    /// `clientObjectPostChanged` event tagged with [observationId]. The first
    /// emission replays the current value to a freshly-subscribed Dart listener.
    private fun startClientObjectPostObservation(observationId: String, clientObjectId: String) {
        clientObjectPostJobs.remove(observationId)?.cancel()
        clientObjectPostJobs[observationId] = scope.launch {
            try {
                OctopusSDK.getClientObjectRelatedPostFlow(clientObjectId).collect { post ->
                    sendEvent(
                        "clientObjectPostChanged",
                        mapOf(
                            "observationId" to observationId,
                            "post" to post?.let { serializeOctopusPost(it) }
                        )
                    )
                }
            } catch (e: CancellationException) {
                // Normal teardown (stopClientObjectPostObservation / stop() /
                // re-subscribe). Rethrow so cancellation keeps propagating —
                // swallowing it would break structured concurrency and log an
                // error for an ordinary unsubscribe.
                throw e
            } catch (e: Exception) {
                Log.e("OctopusSdkFlutter", "client object post observation failed", e)
            }
        }
    }

    /// Collects the community-data flow for the member identified by exactly one
    /// of [profileId] / [clientUserId] and forwards each emission (the data, or
    /// `null`) as a `communityDataChanged` event tagged with [observationId]. The
    /// first emission replays the current value to a freshly-subscribed Dart
    /// listener.
    private fun startCommunityDataObservation(
        observationId: String,
        profileId: String?,
        clientUserId: String?
    ) {
        communityDataJobs.remove(observationId)?.cancel()
        communityDataJobs[observationId] = scope.launch {
            try {
                val flow = if (profileId != null) {
                    OctopusSDK.communityDataFlow(profileId)
                } else {
                    OctopusSDK.communityDataFlowByClientUserId(clientUserId!!)
                }
                flow.collect { data ->
                    sendEvent(
                        "communityDataChanged",
                        mapOf(
                            "observationId" to observationId,
                            "communityData" to data?.let { serializeCommunityData(it) }
                        )
                    )
                }
            } catch (e: CancellationException) {
                // Normal teardown (stopCommunityDataObservation / stop() /
                // re-subscribe). Rethrow so cancellation keeps propagating —
                // swallowing it would break structured concurrency and log an
                // error for an ordinary unsubscribe.
                throw e
            } catch (e: Exception) {
                Log.e("OctopusSdkFlutter", "community data observation failed", e)
            }
        }
    }

    /// Serializes a native [OctopusCommunityData] for the platform channel. The
    /// native `userId` is sent as `profileId` — the wrapper's name for the Octopus
    /// id on every surface (matching iOS and the screen-displayed events).
    private fun serializeCommunityData(data: OctopusCommunityData): Map<String, Any?> = mapOf(
        "profileId" to data.userId,
        "messageCount" to data.messageCount,
        "gamification" to data.gamification?.let {
            mapOf("level" to it.level, "score" to it.score)
        }
    )

    /// Decodes the wire `clientPost` map into a native [ClientPost]. Materializes
    /// a `localImage` attachment's bytes into a temp file ([Resource.Local]);
    /// `remoteImage` becomes a [Resource.Remote] URL.
    private fun decodeClientPost(map: Map<String, Any?>): ClientPost {
        val objectId = map["objectId"] as? String
            ?: throw IllegalArgumentException("objectId is required")
        val text = map["text"] as? String
            ?: throw IllegalArgumentException("text is required")
        @Suppress("UNCHECKED_CAST")
        val attachment = (map["attachment"] as? Map<String, Any?>)?.let { decodeAttachment(it) }
        return ClientPost(
            objectId = objectId,
            text = text,
            attachment = attachment,
            catchPhrase = map["catchPhrase"] as? String,
            viewObjectButtonText = map["viewObjectButtonText"] as? String,
            groupId = map["groupId"] as? String
        )
    }

    private fun decodeAttachment(map: Map<String, Any?>): Resource? {
        return when (map["type"] as? String) {
            "remoteImage" -> (map["url"] as? String)?.let { Resource.Remote(url = it) }
            "localImage" -> {
                val bytes = map["bytes"] as? ByteArray ?: return null
                // Write the original bytes verbatim (no decode/re-encode) and let
                // the native SDK validate format/size. This matches the iOS bridge
                // (which passes the raw Data straight through): re-encoding here
                // would bloat JPEGs to PNG and would silently drop undecodable or
                // empty bytes instead of surfacing a typed ClientPostError.FileError.
                val tempFile = File.createTempFile(
                    "octopus_bridge_image", imageExtensionFor(bytes), context.cacheDir
                )
                tempFile.writeBytes(bytes)
                Resource.Local(tempFile.absolutePath)
            }
            else -> null
        }
    }

    /// Picks a file extension from the image bytes' magic number so the
    /// materialized temp file keeps the host's original format (the native SDK
    /// infers the MIME type from it). Defaults to `.img` for unknown formats.
    private fun imageExtensionFor(bytes: ByteArray): String = when {
        bytes.size >= 3 && bytes[0] == 0xFF.toByte() &&
            bytes[1] == 0xD8.toByte() && bytes[2] == 0xFF.toByte() -> ".jpg"
        bytes.size >= 8 && bytes[0] == 0x89.toByte() && bytes[1] == 0x50.toByte() &&
            bytes[2] == 0x4E.toByte() && bytes[3] == 0x47.toByte() -> ".png"
        bytes.size >= 12 && bytes[0] == 'R'.code.toByte() && bytes[1] == 'I'.code.toByte() &&
            bytes[2] == 'F'.code.toByte() && bytes[3] == 'F'.code.toByte() &&
            bytes[8] == 'W'.code.toByte() && bytes[9] == 'E'.code.toByte() &&
            bytes[10] == 'B'.code.toByte() && bytes[11] == 'P'.code.toByte() -> ".webp"
        else -> ".img"
    }

    /// Encodes an `OctopusResult<OctopusPost, ClientPostError>` into the shared
    /// wire: success carries the serialized post; failures reuse
    /// [encodeOctopusResult] (connection failures + invalidArguments with typed
    /// [ClientPostError]s).
    private fun encodeOctopusPostResult(
        result: OctopusResult<OctopusPost, ClientPostError>
    ): Map<String, Any?> = when (result) {
        is OctopusResult.Success ->
            mapOf("type" to "success", "post" to serializeOctopusPost(result.data))
        else ->
            encodeOctopusResult(result) { e -> encodeClientPostError(e) }
    }

    /// Encodes the success case of [OctopusSDK.fetchGroups] (which on Android
    /// returns `OctopusResult<List<OctopusGroup>, Nothing>`) into the shared
    /// wire: success carries the serialized list using the same 6-field lean
    /// shape published on `groupsChanged`; failures reuse [encodeOctopusResult]
    /// with a no-op error encoder (the Nothing failure-type means no typed
    /// errors can reach this branch).
    private fun encodeGroupListResult(
        result: OctopusResult<List<OctopusGroup>, Nothing>
    ): Map<String, Any?> = when (result) {
        is OctopusResult.Success ->
            mapOf("type" to "success", "groups" to result.data.map { serializeOctopusGroup(it) })
        else ->
            encodeOctopusResult(result) { _ -> emptyMap<String, Any?>() }
    }

    /// Serializes a single [OctopusGroup] using the lean 6-field shape shared
    /// with the [groupsChanged] event (the iOS-intersection public surface).
    private fun serializeOctopusGroup(group: OctopusGroup): Map<String, Any?> = mapOf(
        "id" to group.id,
        "name" to group.name,
        "isFollowed" to group.isFollowed,
        "canChangeFollowStatus" to group.canChangeFollowStatus,
        "canAccess" to group.canAccess,
        "canCreateChildren" to group.canCreateChildren
    )

    /// Maps a native [GroupFollowUnfollowError] leaf onto its Dart wire `type`
    /// + message. Exhaustive over the 6 native variants.
    private fun encodeGroupFollowUnfollowError(
        e: GroupFollowUnfollowError
    ): Map<String, Any?> {
        val type = when (e) {
            is GroupFollowUnfollowError.MissingGroup -> "missingGroup"
            is GroupFollowUnfollowError.UnfollowableGroup -> "unfollowableGroup"
            is GroupFollowUnfollowError.GroupAlreadyFollowed -> "groupAlreadyFollowed"
            is GroupFollowUnfollowError.GroupAlreadyUnfollowed -> "groupAlreadyUnfollowed"
            is GroupFollowUnfollowError.LastFollowedGroup -> "lastFollowedGroup"
            is GroupFollowUnfollowError.Unknown -> "unknown"
        }
        return mapOf("type" to type, "message" to e.errorMessage)
    }

    private fun serializeOctopusPost(post: OctopusPost): Map<String, Any?> = mapOf(
        "id" to post.id,
        "commentCount" to post.commentCount,
        "viewCount" to post.viewCount,
        "reactions" to post.reactions.map {
            mapOf("reactionKind" to reactionKindToWire(it.reactionKind), "count" to it.count)
        },
        "userReactionKind" to post.userReactionKind?.let { reactionKindToWire(it) }
    )

    /// Serializes an [OctopusReactionKind] into the `{kind, serverValue?}` wire
    /// map the Dart `OctopusReactionKind.fromWire` expects.
    private fun reactionKindToWire(kind: OctopusReactionKind): Map<String, Any?> =
        when (val k = kind as? OctopusItem.Reaction.Kind) {
            is OctopusItem.Reaction.Kind.Heart -> mapOf("kind" to "heart")
            is OctopusItem.Reaction.Kind.Joy -> mapOf("kind" to "joy")
            is OctopusItem.Reaction.Kind.MouthOpen -> mapOf("kind" to "mouthOpen")
            is OctopusItem.Reaction.Kind.Clap -> mapOf("kind" to "clap")
            is OctopusItem.Reaction.Kind.Cry -> mapOf("kind" to "cry")
            is OctopusItem.Reaction.Kind.Rage -> mapOf("kind" to "rage")
            is OctopusItem.Reaction.Kind.Unknown ->
                mapOf("kind" to "unknown", "serverValue" to k.unicode)
            null -> mapOf("kind" to "unknown", "serverValue" to kind.unicode)
        }

    /// Maps a native [ClientPostError] leaf onto its Dart wire `type` + message.
    private fun encodeClientPostError(e: ClientPostError): Map<String, Any?> {
        val type = when (e) {
            is ClientPostError.TextError.Missing -> "textMissing"
            is ClientPostError.TextError.MaxCharLimitReached -> "textTooLong"
            is ClientPostError.TextError.Unknown -> "other"
            is ClientPostError.FileError.EmptyFile -> "fileEmpty"
            is ClientPostError.FileError.FileSizeTooBig -> "fileTooLarge"
            is ClientPostError.FileError.BadFileFormat -> "fileBadFormat"
            is ClientPostError.FileError.UploadIssue -> "fileUpload"
            is ClientPostError.FileError.DownloadIssue -> "fileDownload"
            is ClientPostError.FileError.Unknown -> "other"
            is ClientPostError.ClientObjectError.MissingId -> "missingObjectId"
            is ClientPostError.ClientObjectError.MissingCta -> "missingCta"
            is ClientPostError.ClientObjectError.PostUnavailable -> "postUnavailable"
            is ClientPostError.ClientObjectError.PostNotFound -> "postNotFound"
            is ClientPostError.ClientObjectError.PostAlreadyExists -> "postAlreadyExists"
            is ClientPostError.ClientObjectError.InvalidGroupId -> "invalidGroupId"
            is ClientPostError.ClientObjectError.InvalidAuthor -> "invalidAuthor"
            is ClientPostError.ClientObjectError.Unknown -> "other"
            is ClientPostError.TokenError.Invalid -> "tokenInvalid"
            is ClientPostError.TokenError.Expired -> "tokenExpired"
            is ClientPostError.TokenError.Unknown -> "other"
            is ClientPostError.OtherError -> "other"
        }
        return mapOf("type" to type, "message" to e.errorMessage)
    }

    /// Maps a native [ClientUserError] leaf onto its Dart wire `type` + message.
    ///
    /// The wire `type` values are shared with iOS and with the Dart
    /// `ClientUserError.fromWire`; `test/octopus_connect_user_error_parity_test.dart`
    /// asserts the three sides agree. Not every variant exists on both
    /// platforms — Android has no `invalidToken` / `communityAccessDenied`
    /// counterpart, which the Dart doc records.
    private fun encodeClientUserError(e: ClientUserError): Map<String, Any?> {
        val type = when (e) {
            is ClientUserError.MissingToken -> "missingToken"
            is ClientUserError.UserBanned -> "userBanned"
            is ClientUserError.ProfileError -> "profileError"
            is ClientUserError.Other -> "other"
        }
        return mapOf("type" to type, "message" to e.errorMessage)
    }

    // endregion

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

    private fun startProfileCollection() {
        profileJob?.cancel()
        profileJob = scope.launch {
            OctopusSDK.profile.collect { profile ->
                sendEvent(
                    "profileChanged",
                    mapOf(
                        "profile" to profile?.let {
                            mapOf(
                                "entitlements" to it.entitlements.toList(),
                                "clientUserId" to it.clientUserId
                            )
                        }
                    )
                )
            }
        }
    }

    private fun startGroupsCollection() {
        groupsJob?.cancel()
        groupsJob = scope.launch {
            OctopusSDK.groups.collect { groups ->
                sendEvent(
                    "groupsChanged",
                    mapOf(
                        "groups" to groups.map {
                            mapOf(
                                "id" to it.id,
                                "name" to it.name,
                                "isFollowed" to it.isFollowed,
                                "canChangeFollowStatus" to it.canChangeFollowStatus,
                                "canAccess" to it.canAccess,
                                "canCreateChildren" to it.canCreateChildren
                            )
                        }
                    )
                )
            }
        }
    }

    private fun startConnectionStateCollection() {
        connectionStateJob?.cancel()
        connectionStateJob = scope.launch {
            OctopusSDK.connectionState.collect { state ->
                val payload = when (state) {
                    is ConnectionState.NotConnected -> mapOf("connected" to false)
                    is ConnectionState.Connected -> mapOf(
                        "connected" to true,
                        "isGuest" to state.isGuest
                    )
                }
                sendEvent("connectionStateChanged", payload)
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

    /// Collects the process-static [OctopusSDK.isInitialisedFlow] for the whole
    /// plugin lifetime (independent of initialize, so it also tracks the
    /// pre-init `false` state and `stop()` transitions). Events sent before a
    /// Dart listener attaches are dropped; [onListen] re-sends the current
    /// snapshot so late subscribers stay accurate.
    private fun startIsInitialisedCollection() {
        isInitialisedJob?.cancel()
        isInitialisedJob = scope.launch {
            OctopusSDK.isInitialisedFlow.collect { isInitialised ->
                sendEvent(
                    "isInitialisedChanged",
                    mapOf("isInitialised" to isInitialised)
                )
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
                "topicId" to event.groupId,
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

            is OctopusEvent.GroupFollowingChanged -> mapOf(
                "type" to "groupFollowingChanged",
                "groupId" to event.groupId,
                "followed" to event.followed
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

    /**
     * Decodes the wire reaction map sent by Dart into an [OctopusReactionKind],
     * or `null` (remove reaction). The inverse of the Dart `toWire()`.
     *
     * An `unknown` kind is reconstructed as [OctopusItem.Reaction.Kind.Unknown]
     * (carrying the raw `serverValue`); the SDK rejects it with
     * [SetReactionError.UnknownReaction].
     */
    private fun deserializeReactionKind(map: Map<String, Any?>?): OctopusReactionKind? {
        if (map == null) return null
        return when (map["kind"] as? String) {
            "heart" -> OctopusReactionKind.Heart
            "joy" -> OctopusReactionKind.Joy
            "mouthOpen" -> OctopusReactionKind.MouthOpen
            "clap" -> OctopusReactionKind.Clap
            "cry" -> OctopusReactionKind.Cry
            "rage" -> OctopusReactionKind.Rage
            else -> OctopusItem.Reaction.Kind.Unknown((map["serverValue"] as? String) ?: "")
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
                "relatedTopicId" to event.relatedGroupId
            )
            is OctopusEvent.ScreenDisplayed.MainFeed -> mapOf(
                "type" to "mainFeed",
                "feedId" to event.feedId
            )
            OctopusEvent.ScreenDisplayed.Groups -> mapOf("type" to "groups")
            is OctopusEvent.ScreenDisplayed.GroupDetail -> mapOf(
                "type" to "groupDetail",
                "groupId" to event.groupId,
                "source" to when (event.source) {
                    OctopusEvent.ScreenDisplayed.GroupDetail.Source.BRIDGE -> "bridge"
                    OctopusEvent.ScreenDisplayed.GroupDetail.Source.COMMUNITY -> "community"
                }
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
            is OctopusEvent.ScreenDisplayed.Activity -> mapOf("type" to "activity")
            is OctopusEvent.ScreenDisplayed.OtherUserProfile -> mapOf(
                "type" to "otherUserProfile",
                "profileId" to event.profileId
            )
            is OctopusEvent.ScreenDisplayed.OtherUserPosts -> mapOf(
                "type" to "otherUserPosts",
                "profileId" to event.profileId
            )
            is OctopusEvent.ScreenDisplayed.EditProfile -> mapOf("type" to "editProfile")
            is OctopusEvent.ScreenDisplayed.ReportContent -> mapOf("type" to "reportContent")
            is OctopusEvent.ScreenDisplayed.ReportProfile -> mapOf("type" to "reportProfile")
            is OctopusEvent.ScreenDisplayed.ValidateNickname -> mapOf("type" to "validateNickname")
            is OctopusEvent.ScreenDisplayed.SettingsList -> mapOf("type" to "settingsList")
            is OctopusEvent.ScreenDisplayed.SettingsAccount -> mapOf("type" to "settingsAccount")
            is OctopusEvent.ScreenDisplayed.ReportExplanation -> mapOf("type" to "reportExplanation")
            is OctopusEvent.ScreenDisplayed.DeleteAccount -> mapOf("type" to "deleteAccount")
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        // Defensively release the process-static sink so a foreground engine
        // teardown does not leak its EventSink (and through it, the dead
        // FlutterEngine's BinaryMessenger / DartExecutor) for the lifetime of
        // the process. `setStreamHandler(null)` does NOT invoke `onCancel` on
        // the previous handler — the Dart side may have died without sending
        // a cancel message. The compare-and-clear is safe by construction: a
        // no-op if `listeningSink` no longer matches the static sink (e.g.
        // another engine already took over dispatch).
        listeningSink?.let { OctopusEventEmitter.clearEventSink(it) }
        listeningSink = null
        scope.cancel()
        INSTANCE = null
    }

    // EventChannel.StreamHandler implementation
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        listeningSink = events
        OctopusEventEmitter.setEventSink(events)
        // Re-send the current init state so a listener attaching after a
        // transition (e.g. after initialize already completed) is not stuck on
        // the stale default.
        sendEvent("isInitialisedChanged", mapOf("isInitialised" to OctopusSDK.isInitialised))
    }

    override fun onCancel(arguments: Any?) {
        listeningSink?.let { OctopusEventEmitter.clearEventSink(it) }
        listeningSink = null
    }
}

/// How long this bridge waits for Dart to answer a `clientUserTokenRequest`
/// before falling back to an empty token, which this native SDK refuses locally
/// as `ClientUserError.MissingToken`. Generous on purpose: the host's provider
/// usually calls its own backend.
private const val CLIENT_USER_TOKEN_TIMEOUT_MS = 60_000L

/// Encodes a native [OctopusResult] into the platform-channel wire map shared
/// with the Dart side: `{"type":"success"}` or
/// `{"type":"failure","kind":...}` with the connection-failure payload, or
/// `{"kind":"invalidArguments","errors":[...]}` with [encodeError] applied to
/// each typed error. Reusable across all OctopusResult-returning methods.
private fun <E : ServerError> encodeOctopusResult(
    result: OctopusResult<*, E>,
    encodeError: (E) -> Map<String, Any?>
): Map<String, Any?> = when (result) {
    is OctopusResult.Success ->
        mapOf("type" to "success")
    is OctopusResult.Failure.NoNetwork ->
        mapOf("type" to "failure", "kind" to "noNetwork")
    is OctopusResult.Failure.ContentUnavailable ->
        mapOf("type" to "failure", "kind" to "contentUnavailable")
    is OctopusResult.Failure.UserNotAuthenticated ->
        mapOf("type" to "failure", "kind" to "userNotAuthenticated", "reason" to result.reason)
    is OctopusResult.Failure.PermissionDenied ->
        mapOf("type" to "failure", "kind" to "permissionDenied", "reason" to result.reason)
    is OctopusResult.Failure.StatusError ->
        mapOf(
            "type" to "failure",
            "kind" to "statusError",
            "code" to result.code,
            "description" to result.description
        )
    is OctopusResult.Failure.InvalidArguments ->
        mapOf(
            "type" to "failure",
            "kind" to "invalidArguments",
            "errors" to result.errors.map(encodeError)
        )
}

private fun SyncFollowGroupStatus.toWireValue(): String = when (this) {
    SyncFollowGroupStatus.Applied -> "applied"
    SyncFollowGroupStatus.Skipped -> "skipped"
    SyncFollowGroupStatus.GroupNotFound -> "group_not_found"
    SyncFollowGroupStatus.NotFollowable -> "not_followable"
    SyncFollowGroupStatus.NotUnfollowable -> "not_unfollowable"
    SyncFollowGroupStatus.AlreadyFollowed -> "already_followed"
    SyncFollowGroupStatus.AlreadyUnfollowed -> "already_unfollowed"
    SyncFollowGroupStatus.UnknownError -> "unknown_error"
}
