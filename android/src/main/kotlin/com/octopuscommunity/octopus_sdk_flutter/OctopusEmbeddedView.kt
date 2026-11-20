package com.octopuscommunity.octopus_sdk_flutter

import android.app.Application
import android.content.Context
import android.util.Log
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.systemBars
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.ComposeView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.HasDefaultViewModelProviderFactory
import androidx.lifecycle.SavedStateViewModelFactory
import androidx.lifecycle.SAVED_STATE_REGISTRY_OWNER_KEY
import androidx.lifecycle.VIEW_MODEL_STORE_OWNER_KEY
import androidx.lifecycle.enableSavedStateHandles
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.lifecycle.viewmodel.MutableCreationExtras
import androidx.lifecycle.viewmodel.compose.LocalViewModelStoreOwner
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import androidx.savedstate.compose.LocalSavedStateRegistryOwner
import com.octopuscommunity.sdk.OctopusSDK
import com.octopuscommunity.sdk.domain.model.ProfileField
import com.octopuscommunity.sdk.ui.components.NavigationIconType
import com.octopuscommunity.sdk.ui.components.UrlOpeningStrategy
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

private const val DEFAULT_PRIMARY_MAIN = 0xFF2196F3L
private const val DEFAULT_ON_PRIMARY = 0xFFFFFFFFL

internal fun embeddedViewLifecycleState(visible: Boolean, parent: Lifecycle.State): Lifecycle.State =
    if (visible || parent < Lifecycle.State.STARTED) parent else Lifecycle.State.CREATED

class OctopusEmbeddedView(
    private val context: Context,
    private val showBackButton: Boolean = false,
    private val themeMode: String? = null,
    private val primaryMain: Color? = null,
    private val primaryLowContrast: Color? = null,
    private val primaryHighContrast: Color? = null,
    private val onPrimary: Color? = null,
    private val background: Color? = null,
    private val link: Color? = null,
    private val fontFamily: String? = null,
    private val fontWeight: Int? = null,
    private val logoBase64: String? = null,
    private val icons: Map<String, String> = emptyMap(),
    private val navBarTitle: String? = null,
    private val navBarPrimaryColor: Boolean = false,
    private val titleCentered: Boolean = false,
    private val fontSizeTitle1: Int? = null,
    private val fontSizeTitle2: Int? = null,
    private val fontSizeBody1: Int? = null,
    private val fontSizeBody2: Int? = null,
    private val fontSizeCaption1: Int? = null,
    private val fontSizeCaption2: Int? = null,
    private val fontFamilyNavBarTitle: String? = null,
    private val fontSizeNavBarTitle: Int? = null,
    private val onNavigateToLoginCallbackId: String? = null,
    private val onModifyUserCallbackId: String? = null,
    private val interceptUrls: Boolean = false,
    private val interceptProfileTaps: Boolean = false,
    private val deepLink: String? = null,
    private val bottomSafeAreaInsetDp: Int = 0,
    private val showNavBar: Boolean = true,
    private val initialScreen: InitialScreenSpec = InitialScreenSpec.MainFeed,
    private val navBarLeadingAction: NavigationIconType? = null
) : PlatformView, LifecycleOwner, ViewModelStoreOwner, SavedStateRegistryOwner,
    HasDefaultViewModelProviderFactory {

    class Factory(private val messenger: BinaryMessenger) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
        override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
            val view = createView(context, args)
            view.attachVisibilityChannel(messenger, viewId)
            return view
        }

        private fun createView(context: Context, args: Any?): OctopusEmbeddedView = when (args) {
            is Map<*, *> -> {
                val deepLink = args["linkPath"] as? String
                // Precedence rule: a non-empty `linkPath` (push-notification deep
                // link) wins over `initialScreen`. The Dart layer emits both keys
                // in the creation params; this Factory enforces the precedence
                // by substituting `MainFeed` whenever `linkPath` is present, so
                // the deep-link navigation (LaunchedEffect inside the wrapper
                // composable) takes over from the default Home route.
                val initialScreen = if (!deepLink.isNullOrEmpty()) {
                    InitialScreenSpec.MainFeed
                } else {
                    InitialScreenSpec.fromMap(args["initialScreen"])
                }
                // `navigationMode` is iOS-only (wrapped iOS SDK 1.12.2+) and
                // intentionally NOT read here: the Android bridge always drives
                // the SDK through a Compose NavHost, which keeps its back stack
                // across modal hosting, so there is no NavigationView vs
                // NavigationStack choice to make. The Dart layer emits the key
                // for both platforms; Android simply ignores it (no-op).
                //
                // `hasModifyUserHandler` is the second such iOS-only key, and is
                // likewise NOT read here. iOS needs it because the native SDK
                // hides the activity screen's "Edit my profile" item when its
                // separate edit callback is nil; Android drives both edit paths
                // from one native parameter, which the bridge wires
                // unconditionally. Do NOT "fix" that by gating it on this key:
                // the native Android SDK requires the callback in SSO mode with
                // app-managed profile fields, so gating it on the host handler
                // alone would break those integrations. The divergence (the item
                // shows on Android for a host with no `onModifyUser`) is recorded
                // in the CHANGELOG.
                //
                // `fontSizeNavBarItem` is the third iOS-only key, and is
                // likewise NOT read here. The native iOS theme has a dedicated
                // `OctopusTheme.Fonts.navBarItem` slot; the native Android
                // `OctopusTypography` has no counterpart (title1/title2/body1/
                // body2/caption1/caption2 only), so there is nothing to map it
                // onto. Do NOT approximate it by resizing another slot — that
                // would change text the host did not ask to change.
                //
                // `navBarLeadingAction` IS consumed on Android (wrapped native
                // SDK 1.12.1+): the native `OctopusHomeScreen` gained a
                // `leadingNavigationIcon: NavigationIconType?` so a host can
                // override the root leading icon with a Close (X) — useful when
                // the SDK is mounted somewhere it cannot dismiss itself (e.g. a
                // modal route). We map the wire string here; when absent we pass
                // null so the native default (`if (backIcon) Back else null`,
                // driven by `showBackButton`) is preserved. Both Close and Back
                // route their tap to the same `onBack`/`backRequested` event.
                val navBarLeadingAction = when (args["navBarLeadingAction"] as? String) {
                    "close" -> NavigationIconType.Close
                    "back" -> NavigationIconType.Back
                    else -> null
                }
                OctopusEmbeddedView(
                    context = context,
                    showBackButton = args["showBackButton"] as? Boolean ?: false,
                    themeMode = args["themeMode"] as? String,
                    primaryMain = args.getColor("primaryMain"),
                    primaryLowContrast = args.getColor("primaryLowContrast"),
                    primaryHighContrast = args.getColor("primaryHighContrast"),
                    onPrimary = args.getColor("onPrimary"),
                    background = args.getColor("background"),
                    link = args.getColor("link"),
                    fontFamily = args["fontFamily"] as? String,
                    fontWeight = (args["fontWeight"] as? Number)?.toInt(),
                    logoBase64 = args["logoBase64"] as? String,
                    icons = parseIconSources(args["icons"]),
                    navBarTitle = args["navBarTitle"] as? String,
                    navBarPrimaryColor = args["navBarPrimaryColor"] as? Boolean ?: false,
                    titleCentered = args["titleCentered"] as? Boolean ?: false,
                    fontSizeTitle1 = args["fontSizeTitle1"] as? Int,
                    fontSizeTitle2 = args["fontSizeTitle2"] as? Int,
                    fontSizeBody1 = args["fontSizeBody1"] as? Int,
                    fontSizeBody2 = args["fontSizeBody2"] as? Int,
                    fontSizeCaption1 = args["fontSizeCaption1"] as? Int?,
                    fontSizeCaption2 = args["fontSizeCaption2"] as? Int?,
                    fontFamilyNavBarTitle = args["fontFamilyNavBarTitle"] as? String,
                    fontSizeNavBarTitle = (args["fontSizeNavBarTitle"] as? Number)?.toInt(),
                    onNavigateToLoginCallbackId = args["onNavigateToLoginCallbackId"] as? String,
                    onModifyUserCallbackId = args["onModifyUserCallbackId"] as? String,
                    interceptUrls = args["interceptUrls"] as? Boolean ?: false,
                    interceptProfileTaps = args["interceptProfileTaps"] as? Boolean ?: false,
                    deepLink = deepLink,
                    bottomSafeAreaInsetDp = (args["bottomSafeAreaInset"] as? Number)?.toInt() ?: 0,
                    showNavBar = args["showNavBar"] as? Boolean ?: true,
                    initialScreen = initialScreen,
                    navBarLeadingAction = navBarLeadingAction
                )
            }

            else -> OctopusEmbeddedView(context)
        }
    }

    private val containerView = FrameLayout(context)

    override val lifecycle: Lifecycle = LifecycleRegistry(this)
    override val viewModelStore = ViewModelStore()
    private val savedStateController = SavedStateRegistryController.create(this)
    override val savedStateRegistry get() = savedStateController.savedStateRegistry
    override val defaultViewModelProviderFactory = SavedStateViewModelFactory(null, this)
    override val defaultViewModelCreationExtras get() = MutableCreationExtras().apply {
        set(APPLICATION_KEY, context.applicationContext as Application)
        set(SAVED_STATE_REGISTRY_OWNER_KEY, this@OctopusEmbeddedView)
        set(VIEW_MODEL_STORE_OWNER_KEY, this@OctopusEmbeddedView)
    }
    private lateinit var composeView: ComposeView
    private var viewId: Int? = null

    private val lifecycleRegistry = lifecycle as LifecycleRegistry
    private var visible = false
    private var parentLifecycle: Lifecycle? = null
    private var visibilityChannel: MethodChannel? = null
    private var disposed = false

    private fun updateLifecycle() {
        if (disposed) return
        lifecycleRegistry.currentState = embeddedViewLifecycleState(
            visible, parentLifecycle?.currentState ?: Lifecycle.State.CREATED
        )
    }

    private fun attachVisibilityChannel(messenger: BinaryMessenger, viewId: Int) {
        this.viewId = viewId
        visibilityChannel = MethodChannel(messenger, "octopus_sdk_flutter/native_view/$viewId").also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "setVisible" && call.arguments is Boolean) {
                    visible = call.arguments as Boolean
                    updateLifecycle()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    internal fun sendViewEvent(name: String, data: Map<String, Any?>? = null) {
        if (disposed) return
        OctopusSDKFlutterPlugin.sendEvent(name, (data ?: emptyMap()) + mapOf("viewId" to viewId))
    }

    // NavHost and every native BackHandler use this lifecycle. CREATED disables
    // their callbacks while preserving the remembered navigation stack.
    @Composable
    internal fun EmbeddedContent(content: @Composable () -> Unit) {
        val parent = LocalLifecycleOwner.current.lifecycle
        DisposableEffect(parent) {
            parentLifecycle = parent
            val observer = LifecycleEventObserver { _, _ -> updateLifecycle() }
            parent.addObserver(observer)
            updateLifecycle()
            onDispose {
                parent.removeObserver(observer)
                parentLifecycle = null
            }
        }
        CompositionLocalProvider(
            LocalLifecycleOwner provides this,
            LocalViewModelStoreOwner provides this,
            LocalSavedStateRegistryOwner provides this
        ) {
            MaterialTheme(content = content)
        }
    }

    init {
        savedStateController.performAttach()
        savedStateController.performRestore(null)
        enableSavedStateHandles()
        lifecycleRegistry.currentState = Lifecycle.State.CREATED
        // Keep the host lifecycle/back dispatcher, but isolate navigation and VM state.
        containerView.setViewTreeViewModelStoreOwner(this)
        containerView.setViewTreeSavedStateRegistryOwner(this)
        containerView.addView(
            ComposeView(context).apply {
                composeView = this
                isScrollContainer = true
                isVerticalScrollBarEnabled = true
                isHorizontalScrollBarEnabled = false

                setContent {
                    EmbeddedContent {
                        // The SDK is initialised from Dart only (`OctopusSDK.initialize()`),
                        // never at Application startup, so this PlatformView can be mounted
                        // on an uninitialised SDK in two routine ways: a host that builds the
                        // widget before `await OctopusSDK.initialize(...)` resolves, and
                        // Android restoring the host activity in a fresh process (low-memory
                        // kill, "Don't keep activities") before the Flutter engine has re-run
                        // the host's initialisation. Composing then reached
                        // `OctopusSDK.getKoinApp` and brought the process down with
                        // `UninitializedPropertyAccessException`.
                        //
                        // Native SDK 1.13.4 closed most of that: `OctopusHomeScreen` and every
                        // screen from `octopusComposables` wrap themselves in the native
                        // `OctopusContent`, which carries the same guard. `OctopusHomeContent`
                        // — the `showNavBar = false` branch below — does not: it resolves
                        // `koinViewModel<OctopusHomeViewModel>()` directly, since the SDK
                        // expects a host embedding it to supply the `OctopusContent` wrapper
                        // itself. Gating here covers that branch and keeps the whole embedded
                        // view's behaviour one thing rather than a function of which native
                        // composable each option happens to mount.
                        //
                        // The gate is `isInitialised` rather than a `lateinit` check on
                        // `koinApp`: `initialize()` assigns the container before announcing the
                        // SDK as initialised, while `stop()` announces the stop before closing
                        // a container that stays assigned — so a `lateinit` check would also
                        // pass on a stopped SDK and hand composition a closed Koin scope.
                        //
                        // Collected as state rather than read once, so the view fills in on its
                        // own as soon as `initialize()` completes, with no further recomposition
                        // trigger and no host-side remount needed. Same shape as the guard
                        // the native Android SDK carries in its own `OctopusContent`.
                        val isInitialised by OctopusSDK.isInitialisedFlow.collectAsState()
                        if (!isInitialised) {
                            LaunchedEffect(Unit) {
                                Log.w(
                                    "OctopusEmbeddedView",
                                    "The Octopus embedded view was mounted while the SDK is " +
                                        "not initialised (OctopusSDK.initialize() has not " +
                                        "completed yet, or stop() has been called since), so " +
                                        "it rendered nothing. The community appears on its " +
                                        "own once initialisation lands; await " +
                                        "OctopusSDK.initialize() before showing Octopus UI " +
                                        "to avoid the empty frame."
                                )
                            }
                            Box(modifier = Modifier.fillMaxSize())
                            return@EmbeddedContent
                        }
                        OctopusHomeScreen(
                            modifier = Modifier
                                .fillMaxSize()
                                // The PlatformView is always embedded inside the
                                // Flutter `SafeArea` shell on Android, which already
                                // visually owns the system-bar insets (status bar,
                                // navigation bar, gesture pill). Both native
                                // variants we mount here re-read those insets
                                // internally — `OctopusHomeScreen` via its M3
                                // `Scaffold(contentWindowInsets = systemBars)` and
                                // `OctopusHomeContent` via the same `OctopusScaffold`
                                // path — so unless we consume them first the Compose
                                // tree would re-add the status-bar top under the
                                // prod banner AND the gesture-bar bottom under the
                                // floating "Write a post" pill on edge-to-edge
                                // Android (API 35+). Consuming the full `systemBars`
                                // set kills both gaps in one shot, regardless of
                                // which variant `showNavBar` selects.
                                .consumeWindowInsets(WindowInsets.systemBars)
                                .consumeWindowInsets(WindowInsets.ime),
                            showBackButton = showBackButton,
                            themeMode = themeMode,
                            primaryMain = primaryMain,
                            primaryLowContrast = primaryLowContrast,
                            primaryHighContrast = primaryHighContrast,
                            onPrimary = onPrimary,
                            // Qualified: inside this `ComposeView(context).apply { }`
                            // block, the unqualified name `background` resolves to
                            // the receiver's own inherited `View.background: Drawable?`
                            // (shadowing the class's `private val background: Color?`
                            // declared above), not to this class's property. That
                            // mismatch (Drawable? vs Color?) fails to compile, so the
                            // explicit `this@OctopusEmbeddedView` qualifier is required
                            // here, not stylistic. `link` has no such collision with
                            // any `View` member, so it doesn't need qualifying.
                            background = this@OctopusEmbeddedView.background,
                            link = link,
                            fontFamily = fontFamily,
                            fontWeight = fontWeight,
                            logoBase64 = logoBase64,
                            icons = icons,
                            navBarTitle = navBarTitle,
                            navBarPrimaryColor = navBarPrimaryColor,
                            titleCentered = titleCentered,
                            fontSizeTitle1 = fontSizeTitle1,
                            fontSizeTitle2 = fontSizeTitle2,
                            fontSizeBody1 = fontSizeBody1,
                            fontSizeBody2 = fontSizeBody2,
                            fontSizeCaption1 = fontSizeCaption1,
                            fontSizeCaption2 = fontSizeCaption2,
                            fontFamilyNavBarTitle = fontFamilyNavBarTitle,
                            fontSizeNavBarTitle = fontSizeNavBarTitle,
                            onNavigateToLogin = {
                                Log.d(
                                    "OctopusEmbeddedView",
                                    "onNavigateToLogin called - sending event"
                                )
                                sendViewEvent("loginRequired")
                            },
                            onNavigateToProfileEdit = { profileField: ProfileField? ->
                                Log.d(
                                    "OctopusEmbeddedView",
                                    "onNavigateToProfileEdit called - sending event"
                                )
                                val fieldToEdit = when (profileField) {
                                    ProfileField.NICKNAME -> "NICKNAME"
                                    ProfileField.PICTURE -> "PICTURE"
                                    ProfileField.BIO -> "BIO"
                                    null -> null
                                }
                                sendViewEvent(
                                    "editUser",
                                    mapOf("fieldToEdit" to fieldToEdit)
                                )
                            },
                            onBack = {
                                Log.d(
                                    "OctopusEmbeddedView",
                                    "onBack called - sending backRequested event"
                                )
                                sendViewEvent("backRequested")
                            },
                            onNavigateToUrl = if (interceptUrls) { url ->
                                Log.d(
                                    "OctopusEmbeddedView",
                                    "onNavigateToUrl called - sending event"
                                )
                                sendViewEvent(
                                    "navigateToUrl",
                                    mapOf("url" to url)
                                )
                                UrlOpeningStrategy.HandledByApp
                            } else null,
                            // Unified Profile activation switch: the NATIVE SDK
                            // treats a non-null callback as "the host handles
                            // every profile tap" and stops showing its own
                            // profile screens. Wiring it unconditionally would
                            // therefore suppress those screens for every host,
                            // so it stays null unless the Dart side asked for it.
                            onNavigateToProfile = if (interceptProfileTaps) { clientUserId ->
                                Log.d(
                                    "OctopusEmbeddedView",
                                    "onNavigateToProfile called - sending event"
                                )
                                sendViewEvent(
                                    "navigateToProfile",
                                    mapOf("clientUserId" to clientUserId)
                                )
                            } else null,
                            onNavigateToClientObject = { objectId ->
                                Log.d(
                                    "OctopusEmbeddedView",
                                    "onNavigateToClientObject called - sending event"
                                )
                                sendViewEvent(
                                    "navigateToClientObject",
                                    mapOf("objectId" to objectId)
                                )
                            },
                            deepLink = deepLink,
                            bottomSafeAreaInsetDp = bottomSafeAreaInsetDp,
                            showNavBar = showNavBar,
                            initialScreen = initialScreen,
                            leadingNavigationIcon = navBarLeadingAction,
                        )
                    }
                }
            },
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )
    }

    override fun getView() = containerView

    override fun dispose() {
        if (disposed) return
        disposed = true
        visibilityChannel?.setMethodCallHandler(null)
        // Composition cleanup can still use its VMs/scopes; clear them afterwards.
        composeView.disposeComposition()
        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
        viewModelStore.clear()
    }
}

private fun Map<*, *>.getColor(key: String): Color? =
    when (val value = get(key)) {
        is Number -> value.toLong() and 0xFFFFFFFF
        is String -> value.toLongOrNull()?.and(0xFFFFFFFF)
        else -> null
    }?.let {
        Color(it)
    }
