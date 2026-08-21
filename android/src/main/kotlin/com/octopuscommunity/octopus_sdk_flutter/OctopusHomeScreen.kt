package com.octopuscommunity.octopus_sdk_flutter

import android.net.Uri
import android.util.Log
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.navigation.NavDestination.Companion.hasRoute
import androidx.navigation.compose.NavHost
import com.octopuscommunity.sdk.ui.home.OctopusHomeDefaults
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.octopuscommunity.sdk.domain.model.Post
import com.octopuscommunity.sdk.domain.model.ProfileField
import com.octopuscommunity.sdk.ui.OctopusDestination
import com.octopuscommunity.sdk.ui.OctopusTheme
import com.octopuscommunity.sdk.ui.components.NavigationIconType
import com.octopuscommunity.sdk.ui.components.UrlOpeningStrategy
import com.octopuscommunity.sdk.ui.home.OctopusHomeContent as NativeOctopusHomeContent
import com.octopuscommunity.sdk.ui.home.OctopusHomeScreen as NativeOctopusHomeScreen
import com.octopuscommunity.sdk.ui.octopusComposables
import kotlinx.serialization.Serializable

@Serializable
data object OctopusHomeRoute

/**
 * Invisible destination sitting below a bridge-mode start screen (post / group
 * / createPost). Those screens are hosted via [octopusComposables] and dismiss
 * themselves internally by calling the wrapped SDK's `navigateUp()` — which
 * resolves to a plain `NavController.popBackStack()` the bridge cannot
 * intercept (it's black-box library code). When the bridge screen is the
 * sole/start destination that call has nothing to pop and silently no-ops:
 * the SDK's own back chevron does nothing, even though the host's [onBack]
 * (passed down through the Dart API) is correctly wired — the SDK simply
 * never consults it for these non-Home destinations. [BridgeRootRoute]
 * restores the invariant `popBackStack()` assumes: reaching it back (after
 * having navigated forward to the real bridge target) calls the host's
 * [onBack] directly. Mirrors [OctopusCreatePostActivity]'s [RootRoute] fix for
 * the identical class of bug in the standalone create-post editor.
 */
@Serializable
private data object BridgeRootRoute

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OctopusHomeScreen(
    modifier: Modifier = Modifier,
    showBackButton: Boolean = false,
    onNavigateToLogin: () -> Unit,
    onNavigateToProfileEdit: (ProfileField?) -> Unit,
    themeMode: String? = null,
    primaryMain: Color? = null,
    primaryLowContrast: Color? = null,
    primaryHighContrast: Color? = null,
    onPrimary: Color? = null,
    /**
     * Community background color. `null` keeps the native default resolved from
     * [themeMode]. Also drives the top app bar container color when
     * [navBarPrimaryColor] is `false` — see [OctopusFlutterTheme].
     */
    background: Color? = null,
    /** Color of links inside posts and comments. `null` keeps the SDK default. */
    link: Color? = null,
    fontFamily: String? = null,
    fontWeight: Int? = null,
    logoBase64: String? = null,
    navBarTitle: String? = null,
    navBarPrimaryColor: Boolean = false,
    /**
     * Whether to center the title in the native top app bar. Only honored by
     * the `showNavBar = true` branch (`NativeOctopusHomeScreen`); the
     * `OctopusHomeContent` branch renders no top bar, so the flag has no effect
     * there.
     */
    titleCentered: Boolean = false,
    fontSizeTitle1: Int? = null,
    fontSizeTitle2: Int? = null,
    fontSizeBody1: Int? = null,
    fontSizeBody2: Int? = null,
    fontSizeCaption1: Int? = null,
    fontSizeCaption2: Int? = null,
    onBack: (() -> Unit)? = null,
    onNavigateToUrl: ((String) -> UrlOpeningStrategy)? = null,
    onNavigateToClientObject: ((String) -> Unit)? = null,
    /**
     * Unified Profile: handle every profile tap yourself instead of letting the
     * SDK show its native profile screens. **Must stay null unless the Dart host
     * opted in** — the native SDK reads a non-null callback as the activation
     * switch, so wiring it unconditionally would suppress those screens for
     * every existing host. The parameter is the tapped member's `clientUserId`.
     */
    onNavigateToProfile: ((String) -> Unit)? = null,
    deepLink: String? = null,
    /**
     * Extra bottom padding (in dp) the native floating "Write a post" bar
     * should reserve so it sits above the host app's bottom chrome (e.g. the
     * Flutter shell's `BottomNavigationBar`). When `0` the SDK default applies.
     */
    bottomSafeAreaInsetDp: Int = 0,
    /**
     * When `true` (default), mounts the native `OctopusHomeScreen` composable
     * (with its top app bar). When `false`, mounts `OctopusHomeContent`
     * instead — the host app is then expected to render its own title chrome.
     */
    showNavBar: Boolean = true,
    /**
     * Initial screen to mount. Defaults to [InitialScreenSpec.MainFeed]. When
     * a non-null [deepLink] is also provided, the caller is expected to have
     * resolved the precedence already (deep link wins → caller passes
     * `MainFeed` here).
     */
    initialScreen: InitialScreenSpec = InitialScreenSpec.MainFeed,
    /**
     * Optional override for the leading navigation icon on the home root. When
     * non-null, the native `OctopusHomeScreen` renders this icon
     * ([NavigationIconType.Close] / [NavigationIconType.Back]) regardless of
     * [showBackButton], and its tap is routed to [onBack]. When null (default)
     * the native default applies — a back arrow gated by [showBackButton]. Only
     * honored by the `showNavBar = true` branch (`NativeOctopusHomeScreen`); the
     * `OctopusHomeContent` branch renders no top app bar, so it has no effect
     * there.
     */
    leadingNavigationIcon: NavigationIconType? = null
) {
    OctopusFlutterTheme(
        themeMode = themeMode,
        primaryMain = primaryMain,
        primaryLowContrast = primaryLowContrast,
        primaryHighContrast = primaryHighContrast,
        onPrimary = onPrimary,
        background = background,
        link = link,
        fontFamily = fontFamily,
        fontWeight = fontWeight,
        logoBase64 = logoBase64,
        navBarTitle = navBarTitle,
        navBarPrimaryColor = navBarPrimaryColor,
        fontSizeTitle1 = fontSizeTitle1,
        fontSizeTitle2 = fontSizeTitle2,
        fontSizeBody1 = fontSizeBody1,
        fontSizeBody2 = fontSizeBody2,
        fontSizeCaption1 = fontSizeCaption1,
        fontSizeCaption2 = fontSizeCaption2
    ) {
        val navController = rememberNavController()
        val defaultBottom = OctopusHomeDefaults.contentPadding()
        val contentPadding = if (bottomSafeAreaInsetDp > 0) {
            PaddingValues(
                start = 0.dp,
                top = 0.dp,
                end = 0.dp,
                bottom = bottomSafeAreaInsetDp.dp
            )
        } else {
            defaultBottom
        }

        // For bridge-mode initial screens (post / group / activity / profile /
        // createPost), this is the matching SDK destination the user lands
        // directly on — they cannot navigate back to the main feed from there,
        // matching the iOS `OctopusInitialScreen.{post, group, activity,
        // createPost}` semantics (and, for `profile`, iOS's standalone
        // `OctopusProfileScreen` view). `null` for MainFeed, which keeps the
        // existing OctopusHomeRoute path with our Home/HomeContent toggle
        // (unaffected by the BridgeRootRoute wiring below — it already has its
        // own working onBack).
        val bridgeTarget: OctopusDestination? = when (initialScreen) {
            InitialScreenSpec.MainFeed -> null
            is InitialScreenSpec.Post -> OctopusDestination.PostDetails(
                postId = initialScreen.postId,
                origin = OctopusDestination.Origin.CLIENT_APP,
            )
            is InitialScreenSpec.Group -> OctopusDestination.GroupDetails(
                groupId = initialScreen.groupId,
                origin = OctopusDestination.Origin.CLIENT_APP,
            )
            // The native destination takes the two id kinds as two mutually
            // exclusive parameters, which is exactly what MemberId.Source
            // discriminates — so both member-scoped screens below dispatch on
            // the same `when`, no separate wire key per platform.
            is InitialScreenSpec.Activity -> when (initialScreen.member.source) {
                MemberId.Source.CLIENT_USER_ID -> OctopusDestination.Activity(
                    clientUserId = initialScreen.member.id,
                )
                MemberId.Source.PROFILE_ID -> OctopusDestination.Activity(
                    userId = initialScreen.member.id,
                )
            }
            is InitialScreenSpec.Profile -> initialScreen.member?.let { member ->
                when (member.source) {
                    MemberId.Source.CLIENT_USER_ID -> OctopusDestination.ProfileSummary(
                        clientUserId = member.id,
                    )
                    MemberId.Source.PROFILE_ID -> OctopusDestination.ProfileSummary(
                        userId = member.id,
                    )
                }
                // No member → the connected user's own profile. That is the
                // *editable* graph, not `ProfileSummary`, which is read-only
                // even for one's own id (per its native KDoc).
            } ?: OctopusDestination.CurrentUserProfileGraph
            is InitialScreenSpec.CreatePost -> OctopusDestination.CreatePost(
                type = Post.Draft.Type.TEXT,
                groupId = initialScreen.topicId,
                prefilledText = initialScreen.text,
                // No image: bytes are dropped on the embedded create-post
                // entry point (see InitialScreenSpec.CreatePost docs).
                prefilledImageUri = null,
                prefilledCustomActionLabel = initialScreen.ctaLabel,
                prefilledCustomActionUrl = initialScreen.ctaUrl?.toString(),
            )
        }
        val startDestination: Any = bridgeTarget?.let { BridgeRootRoute } ?: OctopusHomeRoute

        if (bridgeTarget != null) {
            // Tracks whether we've reached bridgeTarget at least once, so
            // popping back to BridgeRootRoute fires onBack only after a real
            // visit — not on the initial null back-stack emission (before the
            // NavHost graph attaches) or a premature BridgeRootRoute reading.
            var reachedTarget by remember { mutableStateOf(false) }
            val backStackEntry by navController.currentBackStackEntryAsState()
            LaunchedEffect(backStackEntry) {
                if (backStackEntry?.destination?.hasRoute<BridgeRootRoute>() == true) {
                    if (reachedTarget) onBack?.invoke()
                } else if (backStackEntry != null) {
                    reachedTarget = true
                }
            }
            // Fires once for this bridgeTarget (not re-triggered by later
            // back-stack changes — see OctopusCreatePostActivity's identical
            // pattern for why this must NOT live inside a composable<Route>
            // body). launchSingleTop guards a config-change re-run against a
            // duplicate push onto an already-restored back stack.
            LaunchedEffect(bridgeTarget) {
                navController.navigate(bridgeTarget) {
                    launchSingleTop = true
                }
            }
        }

        NavHost(
            modifier = modifier,
            navController = navController,
            startDestination = startDestination
        ) {
            composable<BridgeRootRoute> {
                Box(modifier = Modifier.fillMaxSize())
            }
            composable<OctopusHomeRoute> {
                if (showNavBar) {
                    NativeOctopusHomeScreen(
                        navController = navController,
                        backIcon = showBackButton,
                        leadingNavigationIcon = leadingNavigationIcon,
                        titleCentered = titleCentered,
                        contentPadding = contentPadding,
                        onBack = { onBack?.invoke() ?: navController.navigateUp() },
                        onNavigateToLogin = onNavigateToLogin,
                        onNavigateToProfileEdit = onNavigateToProfileEdit,
                        onNavigateToClientObject = onNavigateToClientObject,
                        onNavigateToUrl = onNavigateToUrl ?: { UrlOpeningStrategy.HandledByOctopus },
                        onNavigateToProfile = onNavigateToProfile
                    )
                } else {
                    NativeOctopusHomeContent(
                        navController = navController,
                        contentPadding = contentPadding,
                        onNavigateToLogin = onNavigateToLogin,
                        onNavigateToProfileEdit = onNavigateToProfileEdit,
                        onNavigateToClientObject = onNavigateToClientObject,
                        onNavigateToUrl = onNavigateToUrl ?: { UrlOpeningStrategy.HandledByOctopus },
                        onNavigateToProfile = onNavigateToProfile
                    )
                }
            }

            // Octopus SDK Navigation - integrates all Octopus screens
            // (PostDetails, GroupDetails, CreatePost etc. — pushed on top of
            // BridgeRootRoute when `initialScreen` is non-MainFeed).
            //
            // We still don't pass an `onBack` here: `octopusComposables` only
            // consumes one from the Home destination (`OctopusNavigation.kt`);
            // these screens' toolbar back arrow dispatches a plain
            // `navController.navigateUp()` from their own viewModels, with no
            // fallthrough to a host callback. That's exactly why BridgeRootRoute
            // exists above — it gives that navigateUp() something real to pop
            // to, and the effect watching the back stack invokes the host's
            // onBack when it lands there.
            octopusComposables(
                navController = navController,
                // Propagate the host-supplied bottom safe-area inset to the SDK
                // sub-screens too (post/comment detail, create-post, …), not just
                // the main feed above. The embedded platform view consumes the
                // system-bar insets, so without this the post-detail's bottom
                // comment composer + legal disclaimer render inside the gesture
                // nav area and get clipped. Mirror the default container's
                // `OctopusTheme(content = content)` wrapping so theming is
                // unchanged; add the bottom padding only when an inset was given.
                container = { _, content ->
                    OctopusTheme {
                        if (bottomSafeAreaInsetDp > 0) {
                            Box(Modifier.padding(bottom = bottomSafeAreaInsetDp.dp)) {
                                content()
                            }
                        } else {
                            content()
                        }
                    }
                },
                onNavigateToLogin = onNavigateToLogin,
                onNavigateToProfileEdit = onNavigateToProfileEdit,
                onNavigateToClientObject = onNavigateToClientObject,
                onNavigateToUrl = onNavigateToUrl ?: { UrlOpeningStrategy.HandledByOctopus },
                onNavigateToProfile = onNavigateToProfile
            )
        }

        deepLink?.let { link ->
            LaunchedEffect(link) {
                try {
                    navController.navigate(Uri.parse("octopus-sdk://$link"))
                } catch (e: Exception) {
                    Log.w("OctopusHomeScreen", "Deep link navigation failed: $link", e)
                }
            }
        }
    }
}