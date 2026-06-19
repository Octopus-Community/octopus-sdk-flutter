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
) {
    // Resolve the OctopusColorScheme BEFORE constructing OctopusTheme so the
    // top-app-bar configuration can read `background` from the matching
    // dark/light variant. `OctopusTopAppBarKt` reads the colors arg's
    // `containerColor` and only falls back to `OctopusColorScheme.background`
    // when it is `Color.Unspecified` — passing `background` explicitly here
    // guarantees the top app bar surface tracks `themeMode` even on SDK
    // builds where that fallback path doesn't kick in (e.g. a future
    // OctopusTopAppBar refactor would otherwise silently break us).
    val isDark = themeMode == "dark" ||
        (themeMode == null && isSystemInDarkTheme())
    val resolvedScheme = when (themeMode) {
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
        )
    }
    // Title / nav-icon / action-icon colours on the top app bar. The native
    // SDK falls back to `OctopusColorScheme.gray900` for these when the
    // passed `TopAppBarColors` carries `Color.Unspecified`, but in the dark
    // colour scheme `gray900` is darker than `background`, so dark-on-dark
    // text becomes invisible. Force-light foregrounds in dark mode; let
    // the SDK keep its dark-on-light defaults in light mode by passing
    // `Color.Unspecified`. The primary-coloured variant uses the resolved
    // `onPrimary` (set by the host or scheme defaults).
    val resolvedTopAppBarForeground = if (navBarPrimaryColor) {
        onPrimary ?: resolvedScheme.onPrimary
    } else if (isDark) {
        Color.White
    } else {
        Color.Unspecified
    }

    // Container colour for the top app bar, reused for BOTH the resting and the
    // scrolled state. The SDK's profile / group-details / post-details (and
    // create-post) bars attach a `TopAppBarScrollBehavior`, so as content scrolls
    // under them M3 lerps the bar colour from `containerColor` toward
    // `scrolledContainerColor`. We never set the latter, so M3 resolves it to its
    // default token (`surfaceContainer`) read from the ambient colour scheme — a
    // lavender surface in the dark scheme — and the bar turns light on scroll. The
    // feed bar attaches no scroll behavior, so it never lerps and was unaffected.
    // Pin both to the same colour so every SDK top bar stays flat dark on scroll.
    val topAppBarContainerColor = if (navBarPrimaryColor) {
        primaryMain ?: resolvedScheme.primary
    } else {
        resolvedScheme.background
    }

    OctopusTheme(
        topAppBar = OctopusTopAppBarDefaults.topAppBar(
            title = OctopusTopAppBarDefaults.title(
                text = { it ?: navBarTitle }
            ),
            colors = TopAppBarDefaults.topAppBarColors(
                // `navBarPrimaryColor: true` → use the resolved primary tint
                // (typical brand-on-feed pattern). Otherwise track the
                // resolved scheme's `background` so the top app bar follows
                // dark/light. Reading from `resolvedScheme` (not the raw
                // SDK defaults) ensures host-provided `primaryMain` /
                // `primaryHigh` overrides still flow through for the
                // primary-tinted variant. `scrolledContainerColor` is pinned to
                // the same value so M3 doesn't lerp the bar toward its default
                // tonal `surfaceContainer` (lavender in dark) as content scrolls
                // under a `TopAppBarScrollBehavior` (profile / group / post detail).
                containerColor = topAppBarContainerColor,
                scrolledContainerColor = topAppBarContainerColor,
                titleContentColor = resolvedTopAppBarForeground,
                navigationIconContentColor = resolvedTopAppBarForeground,
                actionIconContentColor = resolvedTopAppBarForeground,
            )
        ),
        colorScheme = resolvedScheme,
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
            logo = logoBase64?.base64ToPainter()?.let { painter -> @Composable { painter } }
        ),
        content = content
    )
}

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