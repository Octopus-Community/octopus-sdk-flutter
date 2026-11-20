package com.octopuscommunity.octopus_sdk_flutter

import android.util.Log
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.painter.BitmapPainter
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
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
    icons: Map<String, String> = emptyMap(),
    iconPaths: Map<String, String> = emptyMap(),
    navBarPrimaryColor: Boolean,
    fontSizeTitle1: Int?,
    fontSizeTitle2: Int?,
    fontSizeBody1: Int?,
    fontSizeBody2: Int?,
    fontSizeCaption1: Int?,
    fontSizeCaption2: Int?,
    /**
     * Android-only font of the top app bar title (`OctopusTheme.fontFamilyNavBarTitle`): a
     * `res/font/` resource name of the host app. `null` keeps the bar's own font.
     */
    fontFamilyNavBarTitle: String? = null,
    /**
     * Android-only size of the top app bar title in sp (`OctopusTheme.fontSizeNavBarTitle`).
     * `null` or non-positive keeps the bar's own size.
     */
    fontSizeNavBarTitle: Int? = null,
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
        remember(name) { resolveFontResource(context, name, "fontFamily") }
    }
    // Same resolution for the Android-only bar title font. Unresolved, it keeps the bar's own
    // family (the size, when set, still applies).
    val resolvedNavBarTitleFontFamily = fontFamilyNavBarTitle?.let { name ->
        remember(name) { resolveFontResource(context, name, "fontFamilyNavBarTitle") }
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
    // SDK renders it with the ambient `LocalTextStyle` at 17sp semibold unless
    // we pass one explicitly, and the style we pass REPLACES that default
    // instead of merging with it (`style = textStyle ?: LocalTextStyle.current
    // .copy(fontSize = 17.sp, fontWeight = FontWeight.SemiBold)` in the native
    // `OctopusTopAppBarTitle`, Android SDK 1.16; `nativeNavBarTitleStyle` below
    // copies it, so recheck it on a native bump). A bare
    // `TextStyle(fontFamily = ...)` would therefore drop the font size too, so
    // we have to supply a complete style — and we cannot supply the ambient
    // one, because the title slot's ambient style (Material3's `TopAppBar`
    // `titleLarge`) is only readable from inside that slot, which this call
    // site is not.
    //
    // Known consequence: basing the style on the resolved `body1` (18sp) means
    // a host that sets only a font override also gets the nav bar title at
    // `fontSizeBody1`'s size. `fontSizeBody1` is the knob to take it back, or
    // `fontSizeNavBarTitle`, which is merged on top of this style (below).
    // Declared in `OctopusTheme.fontFamily`'s dartdoc and in the CHANGELOG.
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

    // The Android-only bar title setting (`fontFamilyNavBarTitle` / `fontSizeNavBarTitle`) is
    // MERGED onto the style the title would otherwise get, which is why it needs its own slot:
    // only inside the slot can `LocalTextStyle.current` be read. With no style passed, the native
    // title (1.16+) draws that ambient style at 17sp semibold, so the override is merged onto the
    // same default (`nativeNavBarTitleStyle`). So a size alone keeps the font and the semibold
    // weight, a font alone keeps the 17sp size. When the global font override above already
    // built a complete style, that style is the base instead. Unset, the slot below is exactly
    // the one used before.
    val navBarTitleOverride = navBarTitleStyleOverride(
        resolvedNavBarTitleFontFamily,
        fontSizeNavBarTitle,
    )
    // The slot passes the text through unchanged. A `null` text only reaches it from the main
    // feed, when the feed shows its logo (native 1.16.0+); the default slot then draws the logo.
    // The main feed's text title is passed to the native screen as `titleText` instead (see
    // `OctopusHomeScreen`), with the iOS bridge's precedence.
    val titleSlot: @Composable (String?) -> Unit = if (navBarTitleOverride == null) {
        OctopusTopAppBarDefaults.title(textStyle = navBarTitleTextStyle)
    } else {
        { octopusText ->
            OctopusTopAppBarDefaults.title(
                textStyle = (navBarTitleTextStyle ?: nativeNavBarTitleStyle(LocalTextStyle.current))
                    .merge(navBarTitleOverride),
            )(octopusText)
        }
    }

    val iconPainters = remember(icons, iconPaths) {
        icons.mapNotNull { (slot, source) ->
            decodeIconSource(slot, source)?.asImageBitmap()?.let { slot to BitmapPainter(it) }
        }.toMap() + iconPaths.mapNotNull { (slot, path) ->
            decodeIconFile(slot, path)?.asImageBitmap()?.let { slot to BitmapPainter(it) }
        }.toMap()
    }
    val resolvedIcons = remember(iconPainters) { octopusIconsWithOverrides(iconPainters) }
    OctopusTheme(
        topAppBar = OctopusTopAppBarDefaults.topAppBar(
            title = titleSlot,
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
            icons = resolvedIcons,
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

/**
 * The part of the top app bar title style that the Android-only `fontFamilyNavBarTitle` /
 * `fontSizeNavBarTitle` theme keys set, to be merged onto the bar's own title style; `null` when
 * neither applies (no font resolved and no positive size), so the caller keeps its existing slot.
 */
internal fun navBarTitleStyleOverride(fontFamily: FontFamily?, fontSizeSp: Int?): TextStyle? {
    val size = fontSizeSp?.takeIf { it > 0 }
    if (fontFamily == null && size == null) return null
    return TextStyle(fontFamily = fontFamily, fontSize = size?.sp ?: TextUnit.Unspecified)
}

/**
 * The style the native top app bar title (`OctopusTopAppBarTitle`, Android SDK 1.16+) draws when
 * it is given none: the bar's [ambient] style at 17sp semibold, the iOS navigation title style.
 * The Android-only title keys are merged onto it so that setting one keeps the other defaults.
 */
internal fun nativeNavBarTitleStyle(ambient: TextStyle): TextStyle =
    ambient.copy(fontSize = 17.sp, fontWeight = FontWeight.SemiBold)

/**
 * Resolves [name] to a font resource shipped by the host app under `res/font/`. This name is
 * NEVER read from the Flutter asset bundle (a font declared in the Flutter app's pubspec.yaml is
 * invisible to this native Compose tree). `getIdentifier` returns 0 when there is no match, in
 * which case we log a warning and return `null`, so the caller keeps its default font rather
 * than silently doing nothing.
 */
private fun resolveFontResource(context: android.content.Context, name: String, key: String): FontFamily? {
    val resId = context.resources.getIdentifier(name, "font", context.packageName)
    if (resId != 0) return FontFamily(Font(resId))
    Log.w(
        TAG,
        "$key '$name' was not found under res/font/ in the host app; keeping the default " +
            "font. See OctopusTheme.$key's documentation for how to register a custom font natively."
    )
    return null
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
    this?.let { decodeIconSource("logo", it)?.asImageBitmap()?.let(::BitmapPainter) }
}
