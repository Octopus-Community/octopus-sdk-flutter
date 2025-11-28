package com.octopuscommunity.octopus_sdk_flutter

import android.content.Context
import android.graphics.BitmapFactory
import android.util.Base64
import android.util.Log
import com.octopuscommunity.sdk.OctopusSDK
import com.octopuscommunity.sdk.domain.model.ClientUser
import com.octopuscommunity.sdk.domain.model.ConnectionMode
import com.octopuscommunity.sdk.domain.model.Image
import com.octopuscommunity.sdk.domain.model.ProfileField
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.File

/** OctopusSdkFlutterPlugin */
class OctopusSdkFlutterPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context
    private var isOctopusAuthMode: Boolean = false
    private val eventEmitter = OctopusEventEmitter()

    companion object {
        @Volatile
        private var INSTANCE: OctopusSdkFlutterPlugin? = null

        fun getInstance(): OctopusSdkFlutterPlugin? = INSTANCE

        fun triggerCallback(method: String, callbackId: String) {
            Log.d(
                "OctopusSdkFlutterPlugin",
                "triggerCallback called: method=$method, callbackId=$callbackId"
            )
            INSTANCE?.channel?.invokeMethod(method, callbackId)
            Log.d("OctopusSdkFlutterPlugin", "triggerCallback completed")
        }

        fun triggerCallbackWithArgs(method: String, args: Map<String, Any>) {
            Log.d(
                "OctopusSdkFlutterPlugin",
                "triggerCallbackWithArgs called: method=$method, args=$args"
            )
            INSTANCE?.channel?.invokeMethod(method, args)
            Log.d("OctopusSdkFlutterPlugin", "triggerCallbackWithArgs completed")
        }

        fun sendEvent(eventName: String, data: Map<String, Any?>?) {
            Log.d("OctopusSdkFlutterPlugin", "sendEvent called: eventName=$eventName, data=$data")
            OctopusEventEmitter.getInstance()?.sendEvent(eventName, data)
            Log.d("OctopusSdkFlutterPlugin", "sendEvent completed")
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

            "initializeOctopusSDK" -> {
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
                    "AVATAR", "PICTURE" -> ProfileField.PICTURE
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
            result.success(null)
        } catch (e: Exception) {
            Log.e("OctopusSdkFlutter", "Error initializing Octopus Auth", e)
            result.error("INITIALIZATION_ERROR", e.message, null)
        }
    }

    private fun connectUser(call: MethodCall, result: Result) {
        try {
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

            CoroutineScope(Dispatchers.Main).launch {
                OctopusSDK.connectUser(user = clientUser, tokenProvider = { token })
            }

            result.success(null)
        } catch (e: Exception) {
            Log.e("OctopusSdkFlutter", "Error connecting user", e)
            result.error("CONNECT_ERROR", e.message, null)
        }
    }

    private fun disconnectUser(result: Result) {
        try {
            CoroutineScope(Dispatchers.Main).launch {
                OctopusSDK.disconnectUser()
            }
            result.success(null)
        } catch (e: Exception) {
            Log.e("OctopusSdkFlutter", "Error disconnecting user", e)
            result.error("DISCONNECT_ERROR", e.message, null)
        }
    }

    private fun toSdkImage(value: String?): Image? {
        Log.d("OctopusSdkFlutter", "toSdkImage - input value: $value")
        if (value.isNullOrBlank()) {
            Log.d("OctopusSdkFlutter", "toSdkImage - value is null or blank")
            return null
        }

        return try {
            if (value.startsWith("http")) {
                // It's a URL
                Log.d("OctopusSdkFlutter", "toSdkImage - treating as URL")
                val image = Image.Remote(url = value)
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
                Image.Local(tempFile.absolutePath)
            }
        } catch (e: Exception) {
            Log.e("OctopusSdkFlutter", "Error converting image", e)
            null
        }
    }


    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
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
