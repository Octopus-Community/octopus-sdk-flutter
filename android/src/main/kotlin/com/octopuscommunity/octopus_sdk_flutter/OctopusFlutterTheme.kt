package com.octopuscommunity.octopus_sdk_flutter

import android.graphics.BitmapFactory
import android.util.Base64
import android.util.Log
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.painter.BitmapPainter
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import androidx.core.graphics.toColorInt
import com.octopuscommunity.sdk.ui.OctopusImagesDefaults
import com.octopuscommunity.sdk.ui.OctopusTheme
import com.octopuscommunity.sdk.ui.OctopusTypographyDefaults
import com.octopuscommunity.sdk.ui.components.OctopusTopAppBarDefaults
import com.octopuscommunity.sdk.ui.octopusDarkColorScheme
import com.octopuscommunity.sdk.ui.octopusLightColorScheme

private const val TAG = "OctopusFlutterTheme"

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OctopusFlutterTheme(
    themeMode: String?,
    primaryMain: Color?,
    primaryLowContrast: Color?,
    primaryHighContrast: Color?,
    onPrimary: Color?,
    background: Color?,
    link: Color?,
    fontFamily: String?,
    fontWeight: Int?,
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
            // Host-provided `background` also reaches the top app bar below
            // (`topAppBarContainerColor` reads `resolvedScheme.background`), so
            // the bar keeps tracking the community surface instead of splitting
            // from it.
            background = background ?: defaultColorScheme.background,
            link = link ?: defaultColorScheme.link,
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

    // Resolve a custom font family from a native Android resource. This name is
    // NEVER read from the Flutter asset bundle (a font declared in the Flutter
    // app's pubspec.yaml is invisible to this native Compose tree) — it must
    // match a font resource shipped by the host Android app under
    // `res/font/`. `getIdentifier` returns 0 when there is no match, in which
    // case we log a warning and keep the SDK's default font rather than
    // silently doing nothing.
    val context = LocalContext.current
    val resolvedFontFamily = fontFamily?.let { name ->
        remember(name) {
            val resId = context.resources.getIdentifier(name, "font", context.packageName)
            if (resId != 0) {
                FontFamily(Font(resId))
            } else {
                Log.w(
                    TAG,
                    "fontFamily '$name' was not found under res/font/ in the host app; " +
                        "keeping the default SDK font. See OctopusTheme.fontFamily's " +
                        "documentation for how to register a custom font natively."
                )
                null
            }
        }
    }
    // Unlike fontFamily, a numeric weight needs no native registration:
    // Compose renders the closest matching face the font actually provides.
    // `OctopusTheme.fontWeight` asserts 100-900 on the Dart side, so an
    // out-of-range value only reaches here in a release build. Coerce it into
    // that same range instead of forwarding it raw: `FontWeight(int)` throws
    // IllegalArgumentException outside 1-1000, which would take down the whole
    // SDK screen, and clamping to 100-900 lands on the same weight iOS
    // resolves for the same input rather than diverging from it.
    val resolvedFontWeight = fontWeight?.let { FontWeight(it.coerceIn(100, 900)) }

    val resolvedTypography = OctopusTypographyDefaults.typography().let { defaultTypography ->
        defaultTypography.copy(
            title1 = defaultTypography.title1.withOverrides(
                fontSizeTitle1, resolvedFontFamily, resolvedFontWeight
            ),
            title2 = defaultTypography.title2.withOverrides(
                fontSizeTitle2, resolvedFontFamily, resolvedFontWeight
            ),
            body1 = defaultTypography.body1.withOverrides(
                fontSizeBody1, resolvedFontFamily, resolvedFontWeight
            ),
            body2 = defaultTypography.body2.withOverrides(
                fontSizeBody2, resolvedFontFamily, resolvedFontWeight
            ),
            caption1 = defaultTypography.caption1.withOverrides(
                fontSizeCaption1, resolvedFontFamily, resolvedFontWeight
            ),
            caption2 = defaultTypography.caption2.withOverrides(
                fontSizeCaption2, resolvedFontFamily, resolvedFontWeight
            )
        )
    }

    // The top app bar title has no dedicated typography role of its own; the
    // SDK renders it with the ambient `LocalTextStyle` unless we pass one
    // explicitly, and the style we pass REPLACES that ambient style instead of
    // merging with it (`style = textStyle ?: LocalTextStyle.current` in the
    // native `OctopusTopAppBarTitle`). A bare `TextStyle(fontFamily = ...)`
    // would therefore drop the ambient font size too, so we have to supply a
    // complete style — and we cannot supply the ambient one, because the title
    // slot's real value (`titleLarge`, 22sp, provided by Material3's
    // `TopAppBar`; `headlineSmall`, 24sp, on the medium bar) is only readable
    // from inside that slot, which this call site is not.
    //
    // Known consequence: basing the style on the resolved `body1` (18sp) means
    // a host that sets only a font override also gets the nav bar title at
    // `fontSizeBody1`'s size. `fontSizeBody1` is the knob to take it back.
    // Declared in `OctopusTheme.fontFamily`'s dartdoc and in the CHANGELOG.
    // Fixing it properly needs a merge-capable `textStyle` on the native SDK,
    // which is tracked internally.
    //
    // Only build an explicit style at all when a font override is requested,
    // so the default path keeps the ambient style untouched.
    val navBarTitleTextStyle = if (resolvedFontFamily != null || resolvedFontWeight != null) {
        resolvedTypography.body1.copy(
            fontFamily = resolvedFontFamily ?: resolvedTypography.body1.fontFamily,
            fontWeight = resolvedFontWeight ?: resolvedTypography.body1.fontWeight,
        )
    } else {
        null
    }

    OctopusTheme(
        topAppBar = OctopusTopAppBarDefaults.topAppBar(
            title = OctopusTopAppBarDefaults.title(
                textStyle = navBarTitleTextStyle,
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
        typography = resolvedTypography,
        images = OctopusImagesDefaults.images(
            logo = logoBase64?.base64ToPainter()?.let { painter -> @Composable { painter } }
        ),
        content = content
    )
}

/**
 * Applies an optional font size (in sp), font family and font weight override on top of this
 * [androidx.compose.ui.text.TextStyle], preserving every field left unset (in particular the
 * base style's `fontSize` when [fontFamily]/[fontWeight] are set but [fontSizeSp] isn't).
 */
private fun androidx.compose.ui.text.TextStyle.withOverrides(
    fontSizeSp: Int?,
    fontFamily: FontFamily?,
    fontWeight: FontWeight?
) = copy(
    fontSize = fontSizeSp?.sp ?: fontSize,
    fontFamily = fontFamily ?: this.fontFamily,
    fontWeight = fontWeight ?: this.fontWeight,
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