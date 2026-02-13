package com.octopuscommunity.octopus_sdk_flutter

import android.graphics.BitmapFactory
import android.util.Base64
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.painter.BitmapPainter
import androidx.compose.ui.unit.sp
import androidx.core.graphics.toColorInt
import com.octopuscommunity.sdk.ui.OctopusImagesDefaults
import com.octopuscommunity.sdk.ui.OctopusTheme
import com.octopuscommunity.sdk.ui.OctopusTypographyDefaults
import com.octopuscommunity.sdk.ui.components.OctopusTopAppBarDefaults
import com.octopuscommunity.sdk.ui.octopusDarkColorScheme
import com.octopuscommunity.sdk.ui.octopusLightColorScheme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OctopusFlutterTheme(
    themeMode: String?,
    primaryMain: Color?,
    primaryLowContrast: Color?,
    primaryHighContrast: Color?,
    onPrimary: Color?,
    logoBase64: String?,
    navBarTitle: String?,
    navBarPrimaryColor: Boolean,
    fontSizeTitle1: Int?,
    fontSizeTitle2: Int?,
    fontSizeBody1: Int?,
    fontSizeBody2: Int?,
    fontSizeCaption1: Int?,
    fontSizeCaption2: Int?,
    content: @Composable () -> Unit
) = OctopusTheme(
    topAppBar = OctopusTopAppBarDefaults.topAppBar(
        title = OctopusTopAppBarDefaults.title(
            text = { it ?: navBarTitle }
        ),
        colors = TopAppBarDefaults.topAppBarColors(
            containerColor = primaryMain?.takeIf { navBarPrimaryColor } ?: Color.Unspecified
        )
    ),
    colorScheme = when (themeMode) {
        "dark" -> octopusDarkColorScheme()
        "light" -> octopusLightColorScheme()
        else -> if (isSystemInDarkTheme()) {
            octopusDarkColorScheme()
        } else {
            octopusLightColorScheme()
        }
    }.let { defaultColorScheme ->
        defaultColorScheme.copy(
            primary = primaryMain ?: defaultColorScheme.primary,
            primaryLow = primaryLowContrast ?: defaultColorScheme.primaryLow,
            primaryHigh = primaryHighContrast ?: defaultColorScheme.primaryHigh,
            onPrimary = onPrimary ?: defaultColorScheme.onPrimary,
//                    background = Color(0xFF141414),
//                    onHover = Color(0xFF242526)
        )
    },
    typography = OctopusTypographyDefaults.typography().let { defaultTypography ->
        defaultTypography.copy(
            title1 = fontSizeTitle1?.let {
                defaultTypography.title1.copy(fontSize = it.sp)
            } ?: defaultTypography.title1,
            title2 = fontSizeTitle2?.let {
                defaultTypography.title2.copy(fontSize = it.sp)
            } ?: defaultTypography.title2,
            body1 = fontSizeBody1?.let {
                defaultTypography.body1.copy(fontSize = it.sp)
            } ?: defaultTypography.body1,
            body2 = fontSizeBody2?.let {
                defaultTypography.body2.copy(fontSize = it.sp)
            } ?: defaultTypography.body2,
            caption1 = fontSizeCaption1?.let {
                defaultTypography.caption1.copy(fontSize = it.sp)
            } ?: defaultTypography.caption1,
            caption2 = fontSizeCaption2?.let {
                defaultTypography.caption2.copy(fontSize = it.sp)
            } ?: defaultTypography.caption2
        )
    },
    images = OctopusImagesDefaults.images(
        logo = logoBase64?.base64ToPainter()
    ),
    content = content
)

fun Int.toColor() = Color(this)

private fun parseColorValue(value: Any?, default: Long): Long {
    return when (value) {
        is Number -> value.toLong() and 0xFFFFFFFF
        is String -> value.toLongOrNull()?.and(0xFFFFFFFF) ?: default
        else -> default
    }
}

private fun String.toColor() = Color(toColorInt())

@Composable
fun String?.base64ToPainter() = remember(this) {
    if (isNullOrBlank()) return@remember null

    try {
        val bytes = Base64.decode(
            // Remove data: prefix if present
            if (startsWith("data:")) substringAfter(",") else this,
            Base64.DEFAULT
        )
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?.asImageBitmap()?.let { BitmapPainter(it) }
    } catch (e: Exception) {
        print(e.stackTrace)
        null
    }
}