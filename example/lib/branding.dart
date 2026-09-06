import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import 'design.dart';

/// Platform-slot hue for the in-app platform badge on Home (cadrage report
/// 24 §3.2/§3.3) — Flutter's slot color from the shared launcher-icon
/// generator palette (`PALETTE['Flutter']`). Reserved for the platform
/// badge and, eventually, the launcher icon pill — never used on a semantic
/// element, exactly like the badge/icon-only rule for [sampleNavy] and
/// [sampleAccentBlue].
const Color octopusPlatformSlotColor = Color(0xFF02569B);

/// Dark-mode variant of [octopusPlatformSlotColor] — Flutter's own light blue,
/// the lighter half of the same brand pair.
///
/// The slot hue is a *brand* color, picked to read on the light surface it was
/// drawn on: as badge text over its own 15% tint on `#141414` it measures
/// 2.26:1, under the 4.5:1 floor. This variant measures 7.07:1 on that same
/// fill (9.40:1 on the bare dark surface). Same split, and same reason, as
/// [navAccentColor].
const Color octopusPlatformSlotColorDark = Color(0xFF54C5F8);

/// The platform-slot hue to draw the Home badge in for [brightness].
Color platformSlotColor(Brightness brightness) => brightness == Brightness.dark
    ? octopusPlatformSlotColorDark
    : octopusPlatformSlotColor;

/// Accent used for the selected nav-bar destination and every active control
/// drawn as a **label**.
///
/// Navy on light, [sampleAccentDark] on dark — the shared sample identity's
/// accent pair (see `design.dart`). Posed explicitly rather than left to the
/// Material default, which would resolve the M3 `secondaryContainer`/
/// `onSurface` pair — a different, unbranded color, and on several platforms
/// the default *blue* the identity rules out.
Color navAccentColor(Brightness brightness) => sampleAccent(brightness);

/// Builds the sample app's own Material 3 [ThemeData] for the given
/// [brightness].
///
/// Hand-built rather than derived via `ColorScheme.fromSeed`: a seeded scheme
/// renders a `primary` nobody chose and no token names, it shifts with the
/// Material/Flutter version, and the previous single `copyWith(secondary:)`
/// on top of it left every other seeded role un-reviewed. This is a verbatim
/// port of the Android sample's `ui/theme/Theme.kt` (`LightColorScheme`
/// `DarkColorScheme`), the one already-complete, Figma-annotated source for
/// this palette.
ThemeData buildAppTheme(Brightness brightness) {
  final scheme = brightness == Brightness.dark
      ? const ColorScheme.dark(
          primary: sampleAccentDark,
          onPrimary: sampleAccentInk,
          primaryContainer: Color(0xFF1B2C46), // Android DarkSurfaceLow
          onPrimaryContainer: Color(0xFFDCE9FC),
          secondary: sampleAccentDark,
          onSecondary: sampleAccentInk,
          secondaryContainer: Color(0xFF223353), // Android DarkSurfaceHigh
          onSecondaryContainer: Color(0xFFDCE9FC),
          tertiary: Color(0xFF8FB6E8),
          onTertiary: Color(0xFF0A1220), // Android OctopusNavyDeep
          tertiaryContainer: Color(0xFF1F3A5E),
          onTertiaryContainer: Color(0xFFCFE0F7),
          surface: sampleDarkSurface, // shared identity dark ground
          onSurface: Colors.white, // Figma: grey/900 dark
          surfaceContainerHighest: Color(0xFF4D4D5A), // Figma: grey/300 dark
          onSurfaceVariant: Color(0xFF9AA7B8), // charter dark secondary text
          outline: Color(0xFF9AA7B8), // charter dark secondary text
          outlineVariant: Color(0xFF4D4D5A), // Figma: grey/300 dark
          error: Color(0xFFFFB4AB),
          onError: Color(0xFF690005),
          surfaceContainerLowest: sampleDarkSurface,
          surfaceContainerLow: sampleDarkSurface,
          surfaceContainer: sampleDarkSurface,
          surfaceContainerHigh: Color(0xFF223353), // Android DarkSurfaceHigh
        )
      : const ColorScheme.light(
          primary: sampleNavy,
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFDCE9FC),
          onPrimaryContainer: sampleNavy,
          secondary: sampleAccentBlue,
          onSecondary: sampleAccentInk,
          secondaryContainer: Color(0xFFDCE9FC),
          onSecondaryContainer: sampleNavy,
          tertiary: Color(0xFF6B7685), // charter secondary text
          onTertiary: Colors.white,
          tertiaryContainer: Color(0xFFCFE0F7),
          onTertiaryContainer: sampleNavy,
          surface: Colors.white, // Figma: #FFFFFF
          onSurface: sampleNavy, // charter light text
          surfaceContainerHighest: Color(
            0xFFEEF1F5,
          ), // charter light field surface
          onSurfaceVariant: Color(0xFF616172), // Figma: grey/700
          outline: Color(0xFF6B7685), // charter secondary text
          outlineVariant: Color(0xFFE4E7EC), // charter hairline
          error: Color(0xFFBA1A1A),
          onError: Colors.white,
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: Colors.white,
          surfaceContainer: Colors.white,
          surfaceContainerHigh: Colors.white,
        );
  final accent = navAccentColor(brightness);
  final onAccent = sampleOnAccentColor(brightness);
  // The shared identity's control accent: the brand blue (light) / the
  // lighter dark-theme step (dark) for anything the user has switched ON.
  // Left to Material these would resolve to `primary` (navy on light) or,
  // for a few widgets, the framework's default blue — which the identity
  // rules out explicitly.
  final controlAccent = WidgetStateProperty.resolveWith<Color?>(
    (states) => states.contains(WidgetState.selected)
        ? sampleControlAccent(brightness)
        : null,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    // Navy app bar in both brightnesses: the platform badge pill and its
    // white glyph are drawn for a dark, saturated ground, and a sample that
    // changes chrome color with the OS setting stops being recognisable.
    appBarTheme: const AppBarTheme(
      backgroundColor: sampleNavy,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
    ),
    // Primary buttons swap navy (light) / accent blue (dark) — the charter's
    // `.btn` rule. The app bar stays navy-family in both brightnesses (just
    // above); primary buttons are the one role that follows `accent` into
    // the bright blue on a dark ground, same as every other active control.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: onAccent,
        minimumSize: const Size.fromHeight(48),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: sampleBorderFor(brightness)),
        minimumSize: const Size.fromHeight(48),
        shape: const StadiumBorder(),
      ),
    ),
    switchTheme: SwitchThemeData(
      // The thumb follows the track's ink rather than being white in both
      // themes: white on the dark-theme track collapses to 2.21:1, under the
      // 3:1 a control boundary needs. [sampleOnAccentColor] reads 7.21:1
      // there.
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? onAccent : scheme.outline,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? sampleControlAccent(brightness)
            : scheme.surfaceContainerHighest,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? sampleControlAccent(brightness)
            : scheme.outline,
      ),
    ),
    checkboxTheme: CheckboxThemeData(fillColor: controlAccent),
    radioTheme: RadioThemeData(fillColor: controlAccent),
    // A selected segment is a solid accent-fill pill with its matching ink —
    // the charter's `.seg div.on` rule — in both brightnesses, not a tint.
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? sampleControlAccent(brightness)
              : null,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? sampleOnControlAccent(brightness)
              : scheme.onSurfaceVariant,
        ),
        side: WidgetStatePropertyAll(
          BorderSide(color: sampleBorderFor(brightness)),
        ),
      ),
    ),
    // The selected nav-item accent is navy in light theme, [sampleAccentDark]
    // in dark (same split as [ApiPill] and section labels) — never a fixed
    // accent blue, which falls under the contrast floor as a label/icon
    // color. The indicator is that same accent at 15% alpha over the bar's
    // own container, posed explicitly rather than left to a hand-picked hex.
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: accent.withValues(alpha: 0.15),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          color: states.contains(WidgetState.selected)
              ? accent
              : scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? accent
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

/// Builds an [OctopusTheme] under a host-forced brightness — `null` meaning
/// "follow the ambient system brightness", the same convention the builders
/// below use. Stored rather than a built theme so a preset picked in one
/// brightness still renders correctly once the host pins the other.
typedef OctopusThemeBuilder = OctopusTheme Function(Brightness? brightness);

/// Unified SDK brand theme — the [OctopusTheme] color quadruple handed to the
/// embedded SDK, canonical across Android/Flutter/RN (cadrage report 24
/// §2.6, decision #9). Values are brightness-dependent, same split as the
/// Android sample's `CommunityTheme.kt` `Default` branch: the SDK reads
/// `OctopusTheme`, never `MaterialTheme`, so a themed Flutter chrome doesn't
/// carry over on its own — these are posed explicitly.
///
/// The light-mode primary is the charter's navy (`sampleNavy`, `#0F1B2D`),
/// not the previous `#024C5B` teal — this preset is what the Config screen's
/// "Theme preset" control now calls "Octopus navy" (see [ConfigScreen]/spec
/// 01). Sample-only repaint: the SDK's own default palette (the "SDK
/// default" preset, an unset [OctopusTheme]) is untouched.
///
/// The dark-mode primary is [sampleAccentDark] (`#6FB2FF`), not
/// `sampleAccentBlue` (`#1D88FE`) — navy doesn't contrast on a dark surface,
/// and `sampleAccentBlue` itself is a light-theme fill only: it falls under
/// the 4.5:1 floor once it lands on a raised container (see
/// [sampleAccentDark]'s doc in `design.dart`). `onPrimary` on that dark fill
/// is [sampleAccentInk] (`#142238`, the dark surface color), not white — the
/// same ink/fill pairing every other dark-theme control in this file uses.
/// The low/high-contrast companions on both brightnesses follow the same
/// sheet (`.bn.active .bic` for the low tint, `.sect`/`.m`/code-token colors
/// for the high one) rather than a stray leftover teal/cyan: the SDK CTAs
/// ("See more", "Write a post") and the Account "yumies" progress bar read
/// from these two, so a mismatched hue there showed up as teal/cyan even
/// though the primary itself had already been repainted.
const Color _sdkPrimaryMainLight = Color(0xFF0F1B2D);
const Color _sdkPrimaryLowLight = Color(0xFFDCE9FC);
const Color _sdkPrimaryHighLight = Color(0xFF1D88FE);
const Color _sdkOnPrimaryLight = Colors.white;

const Color _sdkPrimaryMainDark = sampleAccentDark;
const Color _sdkPrimaryLowDark = sampleAccentInk;
const Color _sdkPrimaryHighDark = Color(0xFFDCE9FC);
const Color _sdkOnPrimaryDark = sampleAccentInk;

/// Builds the custom [OctopusTheme] showcased by the Theme scenario:
/// brand colors + the bundled logo.
///
/// The primary quadruple follows [brightness], defaulting to the current
/// *ambient* system brightness ([PlatformDispatcher.instance.platformBrightness])
/// — the same signal the native SDK itself observes when no
/// [OctopusTheme.themeMode] is forced (Compose `isSystemInDarkTheme()` on
/// Android, `UITraitCollection` on iOS), so the two stay in lock-step by
/// construction. [AppState.effectiveOctopusTheme] passes the host's forced
/// brightness instead whenever the Config screen pins Light or Dark: forcing
/// [OctopusThemeMode] on a quadruple built for the *opposite* brightness would
/// hand the SDK, say, the light primary to render in dark mode. [OctopusTheme.themeMode] is
/// intentionally left unset here: the consuming layer
/// ([AppState.effectiveOctopusTheme]) applies the host's Light/Dark/System
/// choice on top, so the Config screen's theme picker stays the single
/// source of truth for light/dark across both the Flutter chrome AND the SDK
/// content.
OctopusTheme brandOctopusTheme(String? logoBase64, {Brightness? brightness}) {
  final isDark =
      (brightness ?? PlatformDispatcher.instance.platformBrightness) ==
      Brightness.dark;
  return OctopusTheme(
    primaryMain: isDark ? _sdkPrimaryMainDark : _sdkPrimaryMainLight,
    primaryLowContrast: isDark ? _sdkPrimaryLowDark : _sdkPrimaryLowLight,
    primaryHighContrast: isDark ? _sdkPrimaryHighDark : _sdkPrimaryHighLight,
    onPrimary: isDark ? _sdkOnPrimaryDark : _sdkOnPrimaryLight,
    logoBase64: logoBase64,
  );
}

/// Deliberately loud surface color for the [OctopusTheme.background] preset —
/// nothing in the SDK default palette looks like it, so a preset that failed to
/// reach the native theme is visible at a glance instead of plausible.
const Color _sampleBackground = Color(0xFF1B1035);

/// Deliberately loud link color, same reasoning as [_sampleBackground].
const Color _sampleLink = Color(0xFFFFC857);

/// Builds the [OctopusTheme] showcased by the Theme scenario's surface preset:
/// the brand colors plus the three keys added on top of them —
/// [OctopusTheme.background], [OctopusTheme.link] and
/// [OctopusTheme.fontSizeNavBarItem].
///
/// `background` and `link` reach both platforms. `fontSizeNavBarItem` is iOS
/// only — the native Android typography has no nav-bar-item slot — so on Android
/// this preset is expected to differ from iOS in nav-bar item size and only
/// there. It is set here anyway, precisely so QA exercises that documented
/// asymmetry rather than assuming it.
///
/// Like [brandOctopusTheme] this leaves [OctopusTheme.themeMode] unset so the
/// Config screen's picker stays the single source of truth; note the fixed
/// `background` does NOT adapt to light/dark, which is exactly the native
/// contract for a host-provided background.
OctopusTheme surfaceOctopusTheme(String? logoBase64, {Brightness? brightness}) {
  return brandOctopusTheme(logoBase64, brightness: brightness).copyWith(
    background: _sampleBackground,
    link: _sampleLink,
    fontSizeNavBarItem: 22,
  );
}

/// Builds an [OctopusTheme] that sets **only** [OctopusTheme.background] and
/// [OctopusTheme.link] — no primary colors, no logo, no font sizes.
///
/// This is the configuration the surface keys made reachable for the first time,
/// and the one worth QA-ing on its own: setting any single key makes the native
/// bridges build a whole theme, so every slot the host did **not** set must fall
/// back to the SDK's own default rather than to a value the wrapper invented.
///
/// What that means on screen: the surface is deep purple and links are amber,
/// while buttons and other primary-colored elements keep the SDK's default
/// primary — a near-black that adapts to light/dark — and specifically do **not**
/// turn blue. A blue primary here means the wrapper substituted a color for the
/// unset primary slots instead of forwarding "unset".
///
/// Text is the second half of the same oracle, and the sharper one on iOS: body
/// and caption text must render at the native scale (18 / 16 / 14 / 12 points)
/// and must still grow when the OS text size is raised in Settings. Noticeably
/// smaller text — or text that ignores the OS setting — means the bridge
/// substituted point sizes for the six font slots this theme never sets.
OctopusTheme surfaceOnlyOctopusTheme() {
  return const OctopusTheme(background: _sampleBackground, link: _sampleLink);
}

/// Loads the bundled `assets/logo.png` as a base64 string for
/// [OctopusTheme.logoBase64]. Returns `null` if the asset can't be read.
Future<String?> loadLogoBase64() async {
  try {
    final bytes = await rootBundle.load('assets/logo.png');
    return base64Encode(bytes.buffer.asUint8List());
  } catch (_) {
    return null;
  }
}
