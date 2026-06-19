package com.octopuscommunity.octopus_sdk_flutter

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.octopuscommunity.sdk.domain.model.CreatePostScreenInfo
import com.octopuscommunity.sdk.domain.model.OctopusPostCTA
import com.octopuscommunity.sdk.domain.model.OctopusPrefilledPost
import com.octopuscommunity.sdk.domain.model.ProfileField
import com.octopuscommunity.sdk.ui.components.OctopusNavigationHandler
import com.octopuscommunity.sdk.ui.components.UrlOpeningStrategy
import com.octopuscommunity.sdk.ui.octopusComposables
import com.octopuscommunity.sdk.ui.posts.create.OctopusCreatePostScreen as NativeOctopusCreatePostScreen
import kotlinx.serialization.Serializable
import java.io.File

/**
 * Full-screen Activity that hosts the native Octopus post editor (Bridge Share).
 *
 * Started from the plugin's `showCreatePostScreen` method call. The editor owns
 * the screen — its native nav bar, X button, group picker, CGU links, and
 * publish flow all behave correctly because the activity is a real Android
 * destination (no PlatformView / NavHost shenanigans, no inset clipping).
 *
 * Prefill payload is passed via Intent extras (the host marshalled the same map
 * that previously flew through the PlatformView creationParams). Image bytes
 * are materialized to a temp file and passed as a `file://` URI so the Intent
 * stays light.
 *
 * On `finish()` (X tap, system back, or publish success) the activity ends and
 * the plugin completes its `Result.success(null)` waiting on the Dart side.
 */
class OctopusCreatePostActivity : ComponentActivity() {

    @Serializable
    private data object CreatePostRoute

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val info = buildInfoFromIntent(intent)
        val themeMode = intent.getStringExtra(EXTRA_THEME_MODE)
        val primaryMain = intent.getColorExtra(EXTRA_PRIMARY_MAIN)
        val primaryLow = intent.getColorExtra(EXTRA_PRIMARY_LOW)
        val primaryHigh = intent.getColorExtra(EXTRA_PRIMARY_HIGH)
        val onPrimary = intent.getColorExtra(EXTRA_ON_PRIMARY)
        val logoBase64 = intent.getStringExtra(EXTRA_LOGO)

        setContent {
            MaterialTheme {
                OctopusFlutterTheme(
                    themeMode = themeMode,
                    primaryMain = primaryMain,
                    primaryLowContrast = primaryLow,
                    primaryHighContrast = primaryHigh,
                    onPrimary = onPrimary,
                    logoBase64 = logoBase64,
                    navBarTitle = null,
                    navBarPrimaryColor = false,
                    fontSizeTitle1 = intent.getIntExtraOrNull(EXTRA_FONT_TITLE1),
                    fontSizeTitle2 = intent.getIntExtraOrNull(EXTRA_FONT_TITLE2),
                    fontSizeBody1 = intent.getIntExtraOrNull(EXTRA_FONT_BODY1),
                    fontSizeBody2 = intent.getIntExtraOrNull(EXTRA_FONT_BODY2),
                    fontSizeCaption1 = intent.getIntExtraOrNull(EXTRA_FONT_CAPTION1),
                    fontSizeCaption2 = intent.getIntExtraOrNull(EXTRA_FONT_CAPTION2)
                ) {
                    val navController = rememberNavController()
                    OctopusNavigationHandler(
                        onNavigateToLogin = {
                            OctopusSDKFlutterPlugin.sendEvent("loginRequired", null)
                            finish()
                        },
                        onNavigateToProfileEdit = { field ->
                            OctopusSDKFlutterPlugin.sendEvent(
                                "editUser",
                                mapOf("fieldToEdit" to when (field) {
                                    ProfileField.NICKNAME -> "NICKNAME"
                                    ProfileField.PICTURE -> "PICTURE"
                                    ProfileField.BIO -> "BIO"
                                    null -> null
                                })
                            )
                            finish()
                        },
                        onNavigateToClientObject = { objectId ->
                            OctopusSDKFlutterPlugin.sendEvent(
                                "navigateToClientObject",
                                mapOf("objectId" to objectId)
                            )
                            finish()
                        },
                        onNavigateToUrl = { UrlOpeningStrategy.HandledByOctopus }
                    ) {
                        NavHost(
                            modifier = Modifier.fillMaxSize(),
                            navController = navController,
                            startDestination = CreatePostRoute
                        ) {
                            composable<CreatePostRoute> {
                                NativeOctopusCreatePostScreen(
                                    navController = navController,
                                    info = info
                                )
                            }
                            // The editor reaches ValidateNickname / magic-link
                            // routes at publish time when the user is a guest or
                            // has an unconfirmed nickname.
                            octopusComposables(
                                navController = navController,
                                onNavigateToLogin = {
                                    OctopusSDKFlutterPlugin.sendEvent("loginRequired", null)
                                    finish()
                                },
                                onNavigateToProfileEdit = { field ->
                                    OctopusSDKFlutterPlugin.sendEvent(
                                        "editUser",
                                        mapOf("fieldToEdit" to when (field) {
                                            ProfileField.NICKNAME -> "NICKNAME"
                                            ProfileField.PICTURE -> "PICTURE"
                                            ProfileField.BIO -> "BIO"
                                            null -> null
                                        })
                                    )
                                    finish()
                                },
                                onNavigateToClientObject = { objectId ->
                                    OctopusSDKFlutterPlugin.sendEvent(
                                        "navigateToClientObject",
                                        mapOf("objectId" to objectId)
                                    )
                                    finish()
                                },
                                onNavigateToUrl = { UrlOpeningStrategy.HandledByOctopus }
                            )
                        }
                    }
                }
            }
        }
    }

    private fun buildInfoFromIntent(intent: Intent): CreatePostScreenInfo {
        return try {
            val text = intent.getStringExtra(EXTRA_TEXT)
            val topicId = intent.getStringExtra(EXTRA_TOPIC_ID)
            val ctaUrl = intent.getStringExtra(EXTRA_CTA_URL)
            val ctaLabel = intent.getStringExtra(EXTRA_CTA_LABEL)
            val imagePath = intent.getStringExtra(EXTRA_IMAGE_PATH)
            val cta = if (ctaUrl != null && ctaLabel != null) {
                OctopusPostCTA(url = Uri.parse(ctaUrl), label = ctaLabel)
            } else null
            val imageUri = imagePath?.let { Uri.fromFile(File(it)) }
            if (text == null && imageUri == null) {
                return CreatePostScreenInfo()
            }
            CreatePostScreenInfo(
                prefilledPost = OctopusPrefilledPost(
                    text = text,
                    image = imageUri,
                    topicId = topicId,
                    cta = cta
                )
            )
        } catch (e: Exception) {
            Log.w("OctopusCreatePostActivity", "Invalid prefill — opening empty editor", e)
            CreatePostScreenInfo()
        }
    }

    companion object {
        private const val EXTRA_TEXT = "octopus.text"
        private const val EXTRA_TOPIC_ID = "octopus.topicId"
        private const val EXTRA_IMAGE_PATH = "octopus.imagePath"
        private const val EXTRA_CTA_URL = "octopus.ctaUrl"
        private const val EXTRA_CTA_LABEL = "octopus.ctaLabel"
        private const val EXTRA_THEME_MODE = "octopus.themeMode"
        private const val EXTRA_PRIMARY_MAIN = "octopus.primaryMain"
        private const val EXTRA_PRIMARY_LOW = "octopus.primaryLow"
        private const val EXTRA_PRIMARY_HIGH = "octopus.primaryHigh"
        private const val EXTRA_ON_PRIMARY = "octopus.onPrimary"
        private const val EXTRA_LOGO = "octopus.logo"
        private const val EXTRA_FONT_TITLE1 = "octopus.fontTitle1"
        private const val EXTRA_FONT_TITLE2 = "octopus.fontTitle2"
        private const val EXTRA_FONT_BODY1 = "octopus.fontBody1"
        private const val EXTRA_FONT_BODY2 = "octopus.fontBody2"
        private const val EXTRA_FONT_CAPTION1 = "octopus.fontCaption1"
        private const val EXTRA_FONT_CAPTION2 = "octopus.fontCaption2"

        /**
         * Builds the Intent the plugin uses to launch the create-post activity.
         * `args` is the same map the Dart-side `showCreatePostScreen` method
         * call passes (mirroring the iOS side).
         */
        fun newIntent(context: Context, args: Map<String, Any?>?): Intent {
            val intent = Intent(context, OctopusCreatePostActivity::class.java)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            args ?: return intent

            @Suppress("UNCHECKED_CAST")
            val prefilled = args["prefilledPost"] as? Map<String, Any?>
            if (prefilled != null) {
                (prefilled["text"] as? String)?.let { intent.putExtra(EXTRA_TEXT, it) }
                (prefilled["topicId"] as? String)?.let { intent.putExtra(EXTRA_TOPIC_ID, it) }
                @Suppress("UNCHECKED_CAST")
                (prefilled["cta"] as? Map<String, Any?>)?.let { cta ->
                    (cta["url"] as? String)?.let { intent.putExtra(EXTRA_CTA_URL, it) }
                    (cta["label"] as? String)?.let { intent.putExtra(EXTRA_CTA_LABEL, it) }
                }
                (prefilled["image"] as? ByteArray)?.let { bytes ->
                    val path = materializeImage(context, bytes)
                    intent.putExtra(EXTRA_IMAGE_PATH, path)
                }
            }

            // Theme / fonts — same wire as the existing PlatformView creationParams
            (args["themeMode"] as? String)?.let { intent.putExtra(EXTRA_THEME_MODE, it) }
            (args["primaryMain"] as? Number)?.let { intent.putExtra(EXTRA_PRIMARY_MAIN, it.toLong()) }
            (args["primaryLowContrast"] as? Number)?.let { intent.putExtra(EXTRA_PRIMARY_LOW, it.toLong()) }
            (args["primaryHighContrast"] as? Number)?.let { intent.putExtra(EXTRA_PRIMARY_HIGH, it.toLong()) }
            (args["onPrimary"] as? Number)?.let { intent.putExtra(EXTRA_ON_PRIMARY, it.toLong()) }
            (args["logoBase64"] as? String)?.let { intent.putExtra(EXTRA_LOGO, it) }
            (args["fontSizeTitle1"] as? Int)?.let { intent.putExtra(EXTRA_FONT_TITLE1, it) }
            (args["fontSizeTitle2"] as? Int)?.let { intent.putExtra(EXTRA_FONT_TITLE2, it) }
            (args["fontSizeBody1"] as? Int)?.let { intent.putExtra(EXTRA_FONT_BODY1, it) }
            (args["fontSizeBody2"] as? Int)?.let { intent.putExtra(EXTRA_FONT_BODY2, it) }
            (args["fontSizeCaption1"] as? Int)?.let { intent.putExtra(EXTRA_FONT_CAPTION1, it) }
            (args["fontSizeCaption2"] as? Int)?.let { intent.putExtra(EXTRA_FONT_CAPTION2, it) }

            return intent
        }

        private fun materializeImage(context: Context, bytes: ByteArray): String {
            val ext = imageExtensionFor(bytes)
            val tempFile = File.createTempFile("octopus_prefilled_image", ext, context.cacheDir)
            tempFile.writeBytes(bytes)
            return tempFile.absolutePath
        }

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
    }
}

private fun Intent.getColorExtra(key: String): Color? {
    if (!hasExtra(key)) return null
    val raw = getLongExtra(key, 0L)
    return Color(raw and 0xFFFFFFFFL)
}

private fun Intent.getIntExtraOrNull(key: String): Int? =
    if (hasExtra(key)) getIntExtra(key, 0) else null
