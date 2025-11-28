package com.octopuscommunity.octopus_sdk_flutter

import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.octopuscommunity.sdk.domain.model.ProfileField
import com.octopuscommunity.sdk.ui.home.OctopusHomeScreen
import com.octopuscommunity.sdk.ui.octopusComposables
import kotlinx.serialization.Serializable

@Serializable
data object OctopusHomeRoute

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OctopusComposeWidget(
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
    fontSizeTitle1: Int? = null,
    fontSizeTitle2: Int? = null,
    fontSizeBody1: Int? = null,
    fontSizeBody2: Int? = null,
    fontSizeCaption1: Int? = null,
    fontSizeCaption2: Int? = null,
    onBack: (() -> Unit)? = null
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

        NavHost(
            modifier = modifier,
            navController = navController,
            startDestination = OctopusHomeRoute
        ) {
            composable<OctopusHomeRoute> {
                OctopusHomeScreen(
                    navController = navController,
                    backIcon = showBackButton,
                    onBack = { onBack?.invoke() ?: navController.navigateUp() },
                    onNavigateToLogin = onNavigateToLogin,
                    onNavigateToProfileEdit = onNavigateToProfileEdit
                )
            }

            // Octopus SDK Navigation - integrates all Octopus screens
            octopusComposables(
                navController = navController,
                onNavigateToLogin = onNavigateToLogin,
                onNavigateToProfileEdit = onNavigateToProfileEdit
            )
        }
    }
}