import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import 'design.dart';
import 'widgets/sample_system_bars.dart';

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
  final dark = brightness == Brightness.dark;
  final scheme = dark
      ? const ColorScheme.dark(
          primary: sampleAccentDark,
          onPrimary: sampleDarkSurface,
          primaryContainer: sampleDarkPrimaryLow,
          onPrimaryContainer: sampleDarkText,
          secondary: sampleAccentDark,
          onSecondary: sampleDarkSurface,
          secondaryContainer: sampleDarkPrimaryLow,
          onSecondaryContainer: sampleDarkText,
          tertiary: sampleDarkPrimaryHigh,
          onTertiary: sampleDarkSurface,
          tertiaryContainer: sampleDarkPrimaryLow,
          onTertiaryContainer: sampleDarkText,
          surface: sampleDarkSurface,
          onSurface: sampleDarkText,
          surfaceTint: Colors.transparent,
          surfaceDim: sampleDarkSurface,
          surfaceBright: sampleDarkCard,
          surfaceContainerHighest: sampleDarkCard,
          onSurfaceVariant: sampleDarkSecondary,
          outline: sampleDarkControlOutline,
          outlineVariant: sampleDarkDivider,
          error: sampleDarkError,
          onError: sampleDarkOnError,
          surfaceContainerLowest: sampleDarkSurface,
          surfaceContainerLow: sampleDarkCard,
          surfaceContainer: sampleDarkCard,
          surfaceContainerHigh: sampleDarkCard,
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
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? sampleDarkSurface : sampleNavy,
      systemOverlayStyle: sampleSystemBarStyle(
        dark ? sampleDarkSurface : sampleNavy,
      ),
      foregroundColor: dark ? sampleDarkText : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: dark ? sampleDarkText : Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: dark ? sampleDarkText : Colors.white),
      actionsIconTheme: IconThemeData(
        color: dark ? sampleDarkText : Colors.white,
      ),
    ),
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
        // The outline is the pill's only boundary, so it takes the control
        // outline (3:1+) in both themes, never the decorative card border.
        side: BorderSide(color: sampleControlOutlineFor(brightness)),
        minimumSize: const Size.fromHeight(48),
        shape: const StadiumBorder(),
      ),
    ),
    switchTheme: SwitchThemeData(
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
          BorderSide(color: sampleControlOutlineFor(brightness)),
        ),
      ),
    ),
    // An interactive chip (action, input, unselected choice/filter) is
    // identified by its outline, so the outline holds 3:1: the control outline
    // in both themes. A selected dark chip takes the accent itself (6.00–8.54:1)
    // so selected and unselected differ by more than the check mark; a selected
    // light chip keeps the Material default over its container fill. Goes one
    // step past the Android sample's `SampleChipColors`, whose unselected
    // light chips still sit under 3:1.
    chipTheme: ChipThemeData(
      side: WidgetStateBorderSide.resolveWith((states) {
        if (!states.contains(WidgetState.selected)) {
          return BorderSide(color: sampleControlOutlineFor(brightness));
        }
        return dark ? const BorderSide(color: sampleAccentDark) : null;
      }),
    ),
    // The selected nav-item accent is navy in light theme, [sampleAccentDark]
    // in dark (same split as [ApiPill] and section labels) — never a fixed
    // accent blue, which falls under the contrast floor as a label/icon
    // color. The indicator is that same accent at 15% alpha over the bar's
    // own container, posed explicitly rather than left to a hand-picked hex.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? sampleDarkCard : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      // off-table: selected navigation indicator, 15% accent overlay
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
  if (!dark) return theme;
  final text = theme.textTheme.apply(
    bodyColor: sampleDarkText,
    displayColor: sampleDarkText,
  );
  return theme.copyWith(
    textTheme: text.copyWith(
      bodyLarge: text.bodyLarge?.copyWith(color: sampleDarkBody),
      bodyMedium: text.bodyMedium?.copyWith(color: sampleDarkBody),
      bodySmall: text.bodySmall?.copyWith(color: sampleDarkSecondary),
      labelSmall: text.labelSmall?.copyWith(color: sampleDarkSecondary),
    ),
    hoverColor: sampleDarkHover,
    highlightColor: sampleDarkHover,
    splashColor: sampleDarkHover,
    dividerColor: sampleDarkDivider,
    cardTheme: const CardThemeData(
      color: sampleDarkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: sampleDarkDivider, width: 1),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: sampleDarkElevated,
      modalBackgroundColor: sampleDarkElevated,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: sampleDarkElevated,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: sampleDarkElevated,
      contentTextStyle: TextStyle(color: sampleDarkBody),
      actionTextColor: sampleAccentDark,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: sampleDarkElevated,
      surfaceTintColor: Colors.transparent,
    ),
    menuTheme: const MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(sampleDarkElevated),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    chipTheme: theme.chipTheme.copyWith(
      backgroundColor: sampleDarkChipFill,
      selectedColor: sampleDarkChipFill,
      labelStyle: const TextStyle(color: sampleAccentDark),
      secondaryLabelStyle: const TextStyle(color: sampleAccentDark),
      checkmarkColor: sampleAccentDark,
      deleteIconColor: sampleAccentDark,
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
/// Dark colors share the Signal constants with the shell; see `design.dart`
/// for the mapping and the roles the Flutter SDK cannot override.
const Color _sdkPrimaryMainLight = Color(0xFF0F1B2D);
const Color _sdkPrimaryLowLight = Color(0xFFDCE9FC);
const Color _sdkPrimaryHighLight = Color(0xFF1D88FE);
const Color _sdkOnPrimaryLight = Colors.white;

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
    primaryMain: isDark ? sampleAccentDark : _sdkPrimaryMainLight,
    primaryLowContrast: isDark ? sampleDarkPrimaryLow : _sdkPrimaryLowLight,
    primaryHighContrast: isDark ? sampleDarkPrimaryHigh : _sdkPrimaryHighLight,
    onPrimary: isDark ? sampleDarkSurface : _sdkOnPrimaryLight,
    background: isDark ? sampleDarkSurface : null,
    link: isDark ? sampleAccentDark : null,
    logoBase64: logoBase64,
  );
}

/// Deliberately loud surface color for the [OctopusTheme.background] preset —
/// nothing in the SDK default palette looks like it, so a preset that failed to
/// reach the native theme is visible at a glance instead of plausible.
// off-table: deliberate SDK background override for the theme scenario
const Color _sampleBackground = Color(0xFF1B1035);

/// Deliberately loud link color, same reasoning as [_sampleBackground].
// off-table: deliberate SDK link override for the theme scenario
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
