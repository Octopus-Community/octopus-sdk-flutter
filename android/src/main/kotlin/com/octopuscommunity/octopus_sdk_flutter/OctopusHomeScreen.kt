package com.octopuscommunity.octopus_sdk_flutter

import android.net.Uri
import android.util.Log
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.navigation.compose.NavHost
import com.octopuscommunity.sdk.ui.home.OctopusHomeDefaults
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.octopuscommunity.sdk.domain.model.Post
import com.octopuscommunity.sdk.domain.model.ProfileField
import com.octopuscommunity.sdk.ui.OctopusDestination
import com.octopuscommunity.sdk.ui.components.UrlOpeningStrategy
import com.octopuscommunity.sdk.ui.home.OctopusHomeContent as NativeOctopusHomeContent
import com.octopuscommunity.sdk.ui.home.OctopusHomeScreen as NativeOctopusHomeScreen
import com.octopuscommunity.sdk.ui.octopusComposables
import kotlinx.serialization.Serializable

@Serializable
data object OctopusHomeRoute

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
    initialScreen: InitialScreenSpec = InitialScreenSpec.MainFeed
) {
    OctopusFlutterTheme(
        themeMode = themeMode,
        primaryMain = primaryMain,
        primaryLowContrast = primaryLowContrast,
        primaryHighContrast = primaryHighContrast,
        onPrimary = onPrimary,
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

        // For bridge-mode initial screens (post / group / createPost) we point
        // the NavHost at the matching SDK destination so the user lands
        // directly on that screen — they cannot navigate back to the main
        // feed from there, matching the iOS `OctopusInitialScreen.{post,
        // group, createPost}` semantics. MainFeed keeps the existing
        // OctopusHomeRoute path with our Home/HomeContent toggle.
        val startDestination: Any = when (initialScreen) {
            InitialScreenSpec.MainFeed -> OctopusHomeRoute
            is InitialScreenSpec.Post -> OctopusDestination.PostDetails(
                postId = initialScreen.postId,
                origin = OctopusDestination.Origin.CLIENT_APP,
            )
            is InitialScreenSpec.Group -> OctopusDestination.GroupDetails(
                groupId = initialScreen.groupId,
                origin = OctopusDestination.Origin.CLIENT_APP,
            )
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

        NavHost(
            modifier = modifier,
            navController = navController,
            startDestination = startDestination
        ) {
            composable<OctopusHomeRoute> {
                if (showNavBar) {
                    NativeOctopusHomeScreen(
                        navController = navController,
                        backIcon = showBackButton,
                        titleCentered = titleCentered,
                        contentPadding = contentPadding,
                        onBack = { onBack?.invoke() ?: navController.navigateUp() },
                        onNavigateToLogin = onNavigateToLogin,
                        onNavigateToProfileEdit = onNavigateToProfileEdit,
                        onNavigateToClientObject = onNavigateToClientObject,
                        onNavigateToUrl = onNavigateToUrl ?: { UrlOpeningStrategy.HandledByOctopus }
                    )
                } else {
                    NativeOctopusHomeContent(
                        navController = navController,
                        contentPadding = contentPadding,
                        onNavigateToLogin = onNavigateToLogin,
                        onNavigateToProfileEdit = onNavigateToProfileEdit,
                        onNavigateToClientObject = onNavigateToClientObject,
                        onNavigateToUrl = onNavigateToUrl ?: { UrlOpeningStrategy.HandledByOctopus }
                    )
                }
            }

            // Octopus SDK Navigation - integrates all Octopus screens
            // (PostDetails, GroupDetails, CreatePost etc. — also serves as
            // the start destination set when `initialScreen` is non-MainFeed).
            //
            // We intentionally do NOT pass an `onBack` here: the SDK's
            // `octopusComposables` only consumes `onBack` from the Home
            // destination (`OctopusNavigation.kt`). The other screens'
            // toolbar back arrow dispatches `navController.navigateUp()`
            // inside their own viewModels, with no fallthrough. As a
            // result, the host has no way to intercept the back tap when
            // a bridge-mode start destination is at the root of the back
            // stack. Bridge-mode dismiss is documented on the standalone
            // widgets as the host's responsibility.
            octopusComposables(
                navController = navController,
                onNavigateToLogin = onNavigateToLogin,
                onNavigateToProfileEdit = onNavigateToProfileEdit,
                onNavigateToClientObject = onNavigateToClientObject,
                onNavigateToUrl = onNavigateToUrl ?: { UrlOpeningStrategy.HandledByOctopus }
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