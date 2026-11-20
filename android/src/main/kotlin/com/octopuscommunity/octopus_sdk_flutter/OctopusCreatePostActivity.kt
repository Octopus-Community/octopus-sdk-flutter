package com.octopuscommunity.octopus_sdk_flutter

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Build
import android.util.Log
import androidx.activity.SystemBarStyle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.toArgb
import androidx.navigation.NavDestination.Companion.hasRoute
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.octopuscommunity.sdk.OctopusSDK
import com.octopuscommunity.sdk.domain.model.CreatePostScreenInfo
import com.octopuscommunity.sdk.domain.model.OctopusLocalizedText
import com.octopuscommunity.sdk.domain.model.OctopusPostCTA
import com.octopuscommunity.sdk.domain.model.OctopusPrefilledPost
import com.octopuscommunity.sdk.domain.model.ProfileField
import com.octopuscommunity.sdk.ui.components.OctopusNavigationHandler
import com.octopuscommunity.sdk.ui.components.UrlOpeningStrategy
import com.octopuscommunity.sdk.ui.octopusComposables
import com.octopuscommunity.sdk.ui.OctopusTheme
import com.octopuscommunity.sdk.ui.OctopusTransitionsDefaults
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
 * that previously flew through the PlatformView creationParams). Each image's
 * bytes are materialized to a temp file and passed as a `file://` URI so the
 * Intent stays light; the files live as long as the editor does.
 *
 * On `finish()` (X tap, system back, or publish success) the activity ends and
 * the plugin completes its `Result.success(null)` waiting on the Dart side.
 *
 * The native editor closes itself by calling the wrapped SDK's internal
 * `navigateUp()`, which — for a screen hosted in a normal multi-destination
 * `NavHost` — pops back to whatever screen came before it. Here `CreatePostRoute`
 * would otherwise be the sole/start destination, so that `popBackStack()` call
 * has nothing to pop and silently no-ops: neither the X button nor a
 * successful publish would ever close the activity (only the OS's own back
 * dispatcher does, since Navigation-Compose stops intercepting system back at
 * the root — which is how a raw back gesture "accidentally" works today).
 * [RootRoute] restores the invariant the SDK assumes: it sits *below*
 * `CreatePostRoute` so `popBackStack()` has something real to pop to, and
 * reaching it back after having visited `CreatePostRoute` finishes the
 * activity.
 */
class OctopusCreatePostActivity : ComponentActivity() {

    @Serializable
    private data object RootRoute

    @Serializable
    private data object CreatePostRoute

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The SDK is initialised from Dart only (`OctopusSDK.initialize()`),
        // never at Application startup. When Android restores this activity in
        // a fresh process — after a process death (low memory, another crash,
        // "Don't keep activities") while the editor was in the foreground —
        // nothing has run `initialize()` yet, and the first Compose frame
        // would crash in `OctopusSDK.getKoinApp` with an
        // `UninitializedPropertyAccessException`. Finish instead: the host's
        // own activity is right below us in the restored task, so this hands
        // control back exactly where the OS put it. Same guard as the RN
        // `OctopusActivity`.
        if (!OctopusSDK.isInitialised) {
            Log.w(TAG, "OctopusCreatePostActivity started while the SDK is not initialised — finishing")
            finish()
            return
        }
        enableEdgeToEdge()

        val info = buildInfoFromIntent(intent)
        val themeMode = intent.getStringExtra(EXTRA_THEME_MODE)
        val primaryMain = intent.getColorExtra(EXTRA_PRIMARY_MAIN)
        val primaryLow = intent.getColorExtra(EXTRA_PRIMARY_LOW)
        val primaryHigh = intent.getColorExtra(EXTRA_PRIMARY_HIGH)
        val onPrimary = intent.getColorExtra(EXTRA_ON_PRIMARY)
        val background = intent.getColorExtra(EXTRA_BACKGROUND)
        val link = intent.getColorExtra(EXTRA_LINK)
        val fontFamily = intent.getStringExtra(EXTRA_FONT_FAMILY)
        val fontWeight = intent.getIntExtraOrNull(EXTRA_FONT_WEIGHT)
        val logoBase64 = intent.getStringExtra(EXTRA_LOGO)

        setContent {
            MaterialTheme {
                OctopusFlutterTheme(
                    themeMode = themeMode,
                    primaryMain = primaryMain,
                    primaryLowContrast = primaryLow,
                    primaryHighContrast = primaryHigh,
                    onPrimary = onPrimary,
                    background = background,
                    link = link,
                    fontFamily = fontFamily,
                    fontWeight = fontWeight,
                    logoBase64 = logoBase64,
                    iconPaths = intent.getBundleExtra(EXTRA_ICONS)?.let { bundle ->
                        bundle.keySet().mapNotNull { key -> bundle.getString(key)?.let { key to it } }.toMap()
                    } ?: emptyMap(),
                    navBarPrimaryColor = false,
                    fontSizeTitle1 = intent.getIntExtraOrNull(EXTRA_FONT_TITLE1),
                    fontSizeTitle2 = intent.getIntExtraOrNull(EXTRA_FONT_TITLE2),
                    fontSizeBody1 = intent.getIntExtraOrNull(EXTRA_FONT_BODY1),
                    fontSizeBody2 = intent.getIntExtraOrNull(EXTRA_FONT_BODY2),
                    fontSizeCaption1 = intent.getIntExtraOrNull(EXTRA_FONT_CAPTION1),
                    fontSizeCaption2 = intent.getIntExtraOrNull(EXTRA_FONT_CAPTION2),
                    fontFamilyNavBarTitle = intent.getStringExtra(EXTRA_FONT_FAMILY_NAV_BAR_TITLE),
                    fontSizeNavBarTitle = intent.getIntExtraOrNull(EXTRA_FONT_SIZE_NAV_BAR_TITLE),
                ) {
                    // Read the same resolved surface as the editor, including forced
                    // Light/Dark and a host-provided background override.
                    val barSurface = OctopusTheme.colorScheme.background
                    SideEffect {
                        val darkSurface = barSurface.luminance() <= 0.179f
                        val style = SystemBarStyle.auto(
                            lightScrim = barSurface.toArgb(),
                            // Before API 26 navigation icons can only be white.
                            darkScrim = if (darkSurface) barSurface.toArgb() else android.graphics.Color.BLACK,
                            detectDarkMode = { darkSurface }
                        )
                        enableEdgeToEdge(statusBarStyle = style, navigationBarStyle = style)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            window.isNavigationBarContrastEnforced = false
                            window.isStatusBarContrastEnforced = false
                        }
                    }
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
                        // Tracks whether we've reached CreatePostRoute at least once, so the
                        // very first back-stack emission (still RootRoute, before the
                        // LaunchedEffect below navigates forward) doesn't finish() early.
                        var reachedCreatePost by remember { mutableStateOf(false) }
                        val backStackEntry by navController.currentBackStackEntryAsState()
                        LaunchedEffect(backStackEntry) {
                            when {
                                backStackEntry?.destination?.hasRoute<CreatePostRoute>() == true ->
                                    reachedCreatePost = true
                                backStackEntry?.destination?.hasRoute<RootRoute>() == true &&
                                    reachedCreatePost -> finish()
                            }
                        }
                        // Fires once per Activity *instance* — but a config change (rotation,
                        // dark-mode toggle, font-scale, multi-window resize) recreates the
                        // Activity while NavController restores its saved back stack via its
                        // own Saver, so this can re-run against an ALREADY-restored
                        // `[RootRoute, CreatePostRoute]` stack. launchSingleTop avoids pushing
                        // a duplicate CreatePostRoute in that case (which would otherwise need
                        // an extra X-tap/back to actually finish the activity).
                        LaunchedEffect(Unit) {
                            navController.navigate(CreatePostRoute) {
                                launchSingleTop = true
                            }
                        }
                        NavHost(
                            modifier = Modifier.fillMaxSize(),
                            navController = navController,
                            startDestination = RootRoute
                        ) {
                            composable<RootRoute> {
                                Box(modifier = Modifier.fillMaxSize())
                            }
                            composable<CreatePostRoute> {
                                NativeOctopusCreatePostScreen(
                                    navController = navController,
                                    info = info
                                )
                            }
                            // The editor reaches ValidateNickname / host login
                            // routes at publish time when the user is a guest or
                            // has an unconfirmed nickname.
                            octopusComposables(
                                navController = navController,
                                // Since native 1.15 the SDK destinations inherit the host NavHost transitions, and this
                                // NavHost sets none (cross-fade). Keep the 1.14 horizontal slide, the Android match for
                                // the iOS navigation push.
                                transitions = OctopusTransitionsDefaults(),
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

    override fun onDestroy() {
        // Keep files through rotation; final dismissal releases this editor's images. Nothing reads
        // the prefilled photos after that: the editor publishes from its ViewModel, which goes with
        // the activity.
        if (isFinishing) {
            cleanupIconFiles(intent)
            cleanupPrefilledImageFiles(intent)
        }
        super.onDestroy()
    }

    private fun buildInfoFromIntent(intent: Intent): CreatePostScreenInfo {
        // Computed up-front so it rides whichever info we return (prefilled,
        // empty, or the catch fallback). The native create-post screen wires it
        // for this editor session and clears it on dispose — we don't call
        // OctopusSDK.setBridgeShareTokenProvider ourselves.
        val bridgeShareTokenProvider = bridgeShareTokenProviderFromIntent(intent)
        return try {
            CreatePostScreenInfo(
                prefilledPost = prefilledPostFromIntent(intent),
                bridgeShareTokenProvider = bridgeShareTokenProvider
            )
        } catch (e: Exception) {
            Log.w(TAG, "Invalid prefill — opening empty editor", e)
            CreatePostScreenInfo(bridgeShareTokenProvider = bridgeShareTokenProvider)
        }
    }

    /**
     * The bridge-share token provider wired to the Dart side, or `null` when the
     * host registered none. When set, the native editor invokes it at publish
     * time for a prefilled share carrying an image (community forbids member
     * pictures); the lambda runs the same native→Dart bridge-token round-trip
     * as `fetchOrCreateClientObjectRelatedPost`, keyed by the Dart-supplied
     * requestId. Passing it through the public [CreatePostScreenInfo] field lets
     * the native screen own the provider's lifecycle (wire on open via its
     * `@OptIn(InternalOctopusApi)` `setBridgeShareTokenProvider`, clear on
     * dispose) — so this bridge never opts into the internal API itself.
     */
    private fun bridgeShareTokenProviderFromIntent(
        intent: Intent
    ): (suspend (bridgeFingerprint: String) -> String?)? {
        val requestId = intent.getStringExtra(EXTRA_BRIDGE_TOKEN_REQUEST_ID) ?: return null
        return { fingerprint ->
            OctopusSDKFlutterPlugin.requestBridgeToken(requestId, fingerprint)
        }
    }

    companion object {
        private const val TAG = "OctopusSdkFlutter"
        private const val EXTRA_TEXT = "octopus.text"
        private const val EXTRA_BRIDGE_TOKEN_REQUEST_ID = "octopus.bridgeTokenRequestId"
        private const val EXTRA_TOPIC_ID = "octopus.topicId"
        private const val EXTRA_IMAGE_PATHS = "octopus.imagePaths"
        private const val EXTRA_CTA_URL = "octopus.ctaUrl"
        private const val EXTRA_CTA_LABEL = "octopus.ctaLabel"
        private const val EXTRA_CTA_LABEL_DEFAULT_LANGUAGE = "octopus.ctaLabelDefaultLanguage"
        private const val EXTRA_CTA_LABEL_LANGUAGES = "octopus.ctaLabelLanguages"
        private const val EXTRA_CTA_LABEL_TEXTS = "octopus.ctaLabelTexts"
        private const val EXTRA_THEME_MODE = "octopus.themeMode"
        private const val EXTRA_PRIMARY_MAIN = "octopus.primaryMain"
        private const val EXTRA_PRIMARY_LOW = "octopus.primaryLow"
        private const val EXTRA_PRIMARY_HIGH = "octopus.primaryHigh"
        private const val EXTRA_ON_PRIMARY = "octopus.onPrimary"
        private const val EXTRA_BACKGROUND = "octopus.background"
        private const val EXTRA_LINK = "octopus.link"
        private const val EXTRA_FONT_FAMILY = "octopus.fontFamily"
        private const val EXTRA_FONT_WEIGHT = "octopus.fontWeight"
        private const val EXTRA_LOGO = "octopus.logo"
        private const val EXTRA_ICONS = "octopus.icons"
        private const val EXTRA_FONT_TITLE1 = "octopus.fontTitle1"
        private const val EXTRA_FONT_TITLE2 = "octopus.fontTitle2"
        private const val EXTRA_FONT_BODY1 = "octopus.fontBody1"
        private const val EXTRA_FONT_BODY2 = "octopus.fontBody2"
        private const val EXTRA_FONT_CAPTION1 = "octopus.fontCaption1"
        private const val EXTRA_FONT_CAPTION2 = "octopus.fontCaption2"
        private const val EXTRA_FONT_FAMILY_NAV_BAR_TITLE = "octopus.fontFamilyNavBarTitle"
        private const val EXTRA_FONT_SIZE_NAV_BAR_TITLE = "octopus.fontSizeNavBarTitle"

        /**
         * Builds the Intent the plugin uses to launch the create-post activity.
         * `args` is the same map the Dart-side `showCreatePostScreen` method
         * call passes (mirroring the iOS side).
         */
        fun newIntent(context: Context, args: Map<String, Any?>?): Intent {
            val intent = Intent(context, OctopusCreatePostActivity::class.java)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            args ?: return intent

            // Bridge-share token round-trip id: present only when the host set
            // CreatePostScreenInfo.bridgeShareTokenProvider. The activity rebuilds
            // a suspend lambda from it that calls back into Dart at publish time.
            (args["bridgeTokenRequestId"] as? String)?.let {
                intent.putExtra(EXTRA_BRIDGE_TOKEN_REQUEST_ID, it)
            }

            @Suppress("UNCHECKED_CAST")
            val prefilled = args["prefilledPost"] as? Map<String, Any?>
            if (prefilled != null) {
                (prefilled["text"] as? String)?.let { intent.putExtra(EXTRA_TEXT, it) }
                (prefilled["topicId"] as? String)?.let { intent.putExtra(EXTRA_TOPIC_ID, it) }
                @Suppress("UNCHECKED_CAST")
                (prefilled["cta"] as? Map<String, Any?>)?.let { cta ->
                    (cta["url"] as? String)?.let { intent.putExtra(EXTRA_CTA_URL, it) }
                    val localizedLabel = cta["localizedLabel"] as? Map<*, *>
                    val autoTranslatedText = localizedLabel
                        ?.takeIf { it["type"] == "autoTranslated" }
                        ?.get("text") as? String
                    (autoTranslatedText ?: cta["label"] as? String)?.let {
                        intent.putExtra(EXTRA_CTA_LABEL, it)
                    }
                    putPerLanguageLabelExtras(intent, localizedLabel)
                }
                val imagePaths = materializeImages(context, prefilled["images"])
                if (imagePaths.isNotEmpty()) intent.putExtra(EXTRA_IMAGE_PATHS, imagePaths.toTypedArray())
            }

            // Theme / fonts — same wire as the existing PlatformView creationParams
            (args["themeMode"] as? String)?.let { intent.putExtra(EXTRA_THEME_MODE, it) }
            (args["primaryMain"] as? Number)?.let { intent.putExtra(EXTRA_PRIMARY_MAIN, it.toLong()) }
            (args["primaryLowContrast"] as? Number)?.let { intent.putExtra(EXTRA_PRIMARY_LOW, it.toLong()) }
            (args["primaryHighContrast"] as? Number)?.let { intent.putExtra(EXTRA_PRIMARY_HIGH, it.toLong()) }
            (args["onPrimary"] as? Number)?.let { intent.putExtra(EXTRA_ON_PRIMARY, it.toLong()) }
            (args["background"] as? Number)?.let { intent.putExtra(EXTRA_BACKGROUND, it.toLong()) }
            (args["link"] as? Number)?.let { intent.putExtra(EXTRA_LINK, it.toLong()) }
            (args["fontFamily"] as? String)?.let { intent.putExtra(EXTRA_FONT_FAMILY, it) }
            (args["fontWeight"] as? Number)?.let { intent.putExtra(EXTRA_FONT_WEIGHT, it.toInt()) }
            (args["logoBase64"] as? String)?.let { intent.putExtra(EXTRA_LOGO, it) }
            val iconBundle = android.os.Bundle()
            parseIconSources(args["icons"]).forEach { (slot, source) ->
                iconOrDefault(slot) {
                    iconBytes(slot, source)?.let { bytes ->
                        materializeImage(context, bytes, "octopus_icon_")
                    }
                }?.let { path -> iconBundle.putString(slot, path) }
            }
            intent.putExtra(EXTRA_ICONS, iconBundle)
            (args["fontSizeTitle1"] as? Int)?.let { intent.putExtra(EXTRA_FONT_TITLE1, it) }
            (args["fontSizeTitle2"] as? Int)?.let { intent.putExtra(EXTRA_FONT_TITLE2, it) }
            (args["fontSizeBody1"] as? Int)?.let { intent.putExtra(EXTRA_FONT_BODY1, it) }
            (args["fontSizeBody2"] as? Int)?.let { intent.putExtra(EXTRA_FONT_BODY2, it) }
            (args["fontSizeCaption1"] as? Int)?.let { intent.putExtra(EXTRA_FONT_CAPTION1, it) }
            (args["fontSizeCaption2"] as? Int)?.let { intent.putExtra(EXTRA_FONT_CAPTION2, it) }
            (args["fontFamilyNavBarTitle"] as? String)?.let { intent.putExtra(EXTRA_FONT_FAMILY_NAV_BAR_TITLE, it) }
            (args["fontSizeNavBarTitle"] as? Number)?.let { intent.putExtra(EXTRA_FONT_SIZE_NAV_BAR_TITLE, it.toInt()) }
            // `fontSizeNavBarItem` is deliberately NOT forwarded: the native
            // Android `OctopusTypography` has no nav-bar-item slot to map it
            // onto. See the Factory comment in `OctopusEmbeddedView.kt`.

            return intent
        }

        /**
         * The native prefilled post the [newIntent] extras carry, or `null` when they carry none.
         *
         * Text and images are all optional since native 1.13: a topicId- or CTA-only prefill opens
         * the editor on the preselected group with empty, user-editable fields. Only a wholly empty
         * prefill is dropped — it is indistinguishable from opening a plain editor.
         *
         * @throws IllegalArgumentException when the native constructor refuses the payload.
         */
        internal fun prefilledPostFromIntent(intent: Intent): OctopusPrefilledPost? {
            val text = intent.getStringExtra(EXTRA_TEXT)
            val topicId = intent.getStringExtra(EXTRA_TOPIC_ID)
            val ctaUrl = intent.getStringExtra(EXTRA_CTA_URL)
            val ctaLabel = intent.getStringExtra(EXTRA_CTA_LABEL)
            // A per-language label the native SDK refuses drops the CTA only, as the iOS bridge
            // does: the text, images and group still prefill the editor.
            val localizedLabel = try {
                perLanguageLabelFromExtras(intent) ?: ctaLabel?.let { OctopusLocalizedText.AutoTranslated(it) }
            } catch (e: OctopusLocalizedText.ValidationError) {
                Log.w(TAG, "Prefilled CTA label refused — opening the editor without the CTA", e)
                null
            }
            val cta = if (ctaUrl != null && localizedLabel != null) {
                OctopusPostCTA(url = Uri.parse(ctaUrl), localizedLabel = localizedLabel)
            } else null
            val imageUris = intent.getStringArrayExtra(EXTRA_IMAGE_PATHS).orEmpty()
                .map { Uri.fromFile(File(it)) }
            if (text == null && imageUris.isEmpty() && topicId == null && cta == null) return null
            return OctopusPrefilledPost(text = text, topicId = topicId, cta = cta, images = imageUris)
        }

        /**
         * Carries a per-language CTA label (the wire `localizedLabel`) in the intent as three
         * extras, since an intent extra cannot be a map. An auto-translated label needs none: the
         * plain label extra is that text.
         */
        private fun putPerLanguageLabelExtras(intent: Intent, localizedLabel: Map<*, *>?) {
            if (localizedLabel?.get("type") != "perLanguage") return
            val entries = (localizedLabel["texts"] as? List<*>).orEmpty().mapNotNull { it as? Map<*, *> }
            intent.putExtra(EXTRA_CTA_LABEL_DEFAULT_LANGUAGE, localizedLabel["defaultLanguage"] as? String ?: "")
            intent.putExtra(EXTRA_CTA_LABEL_LANGUAGES, entries.map { it["language"] as? String ?: "" }.toTypedArray())
            intent.putExtra(EXTRA_CTA_LABEL_TEXTS, entries.map { it["text"] as? String ?: "" }.toTypedArray())
        }

        /**
         * The per-language CTA label [putPerLanguageLabelExtras] carried, or `null` when there is none.
         *
         * @throws OctopusLocalizedText.ValidationError when the native SDK refuses it.
         */
        private fun perLanguageLabelFromExtras(intent: Intent): OctopusLocalizedText? {
            val defaultLanguage = intent.getStringExtra(EXTRA_CTA_LABEL_DEFAULT_LANGUAGE) ?: return null
            val languages = intent.getStringArrayExtra(EXTRA_CTA_LABEL_LANGUAGES).orEmpty()
            val texts = intent.getStringArrayExtra(EXTRA_CTA_LABEL_TEXTS).orEmpty()
            return decodeLocalizedText(
                mapOf(
                    "type" to "perLanguage",
                    "texts" to languages.zip(texts).map { (language, text) ->
                        mapOf("language" to language, "text" to text)
                    },
                    "defaultLanguage" to defaultLanguage,
                )
            )
        }

        /** Deletes the temp files [newIntent] wrote the prefilled images to. */
        internal fun cleanupPrefilledImageFiles(intent: Intent) {
            intent.getStringArrayExtra(EXTRA_IMAGE_PATHS)?.forEach { path ->
                if (!File(path).delete()) Log.w(TAG, "Could not remove a cached prefilled image")
            }
        }

        /**
         * Writes each non-empty byte array of the wire `images` list to its own temp file, in order,
         * and returns their paths. A failure removes the files already written before rethrowing.
         */
        private fun materializeImages(context: Context, rawImages: Any?): List<String> {
            val paths = mutableListOf<String>()
            try {
                (rawImages as? List<*>).orEmpty().forEach { raw ->
                    val bytes = raw as? ByteArray
                    if (bytes != null && bytes.isNotEmpty()) paths += materializeImage(context, bytes)
                }
            } catch (e: Exception) {
                paths.forEach { File(it).delete() }
                throw e
            }
            return paths
        }

        internal fun cleanupIconFiles(intent: Intent) {
            intent.getBundleExtra(EXTRA_ICONS)?.let { bundle ->
                bundle.keySet().forEach { slot ->
                    bundle.getString(slot)?.let { path ->
                        if (!File(path).delete()) Log.w(TAG, "Could not remove cached icon $slot")
                    }
                }
            }
        }

        private fun materializeImage(context: Context, bytes: ByteArray, prefix: String = "octopus_prefilled_image"): String {
            val ext = imageExtensionFor(bytes)
            val tempFile = File.createTempFile(prefix, ext, context.cacheDir)
            try {
                tempFile.writeBytes(bytes)
            } catch (e: Exception) {
                tempFile.delete()
                throw e
            }
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
