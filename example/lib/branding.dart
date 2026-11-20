import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import 'design.dart';
import 'widgets/sample_system_bars.dart';

/// Accessible accent ink for navigation and text controls.
Color navAccentColor(Brightness brightness) => sampleAccent(brightness);

/// Material/Cupertino-adaptive components share the DS roles in design.dart.
ThemeData buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final surface = sampleTintFor(brightness);
  final text = dark ? sampleDarkText : sampleNavy;
  final secondary = dark ? sampleDarkSecondary : sampleLightSecondary;
  final accent = sampleAccent(brightness);
  final button = sampleButtonBackground(brightness);
  final container = dark
      ? sampleDarkAccentContainer
      : sampleLightAccentContainer;
  final onContainer = dark
      ? sampleDarkOnAccentContainer
      : sampleLightOnAccentContainer;
  final surface2 = dark ? sampleDarkElevated : sampleLightSurface2;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: button,
    onPrimary: sampleTint,
    primaryContainer: container,
    onPrimaryContainer: onContainer,
    secondary: accent,
    onSecondary: dark ? sampleDarkSurface : sampleTint,
    secondaryContainer: container,
    onSecondaryContainer: onContainer,
    tertiary: accent,
    onTertiary: dark ? sampleDarkSurface : sampleTint,
    tertiaryContainer: dark ? sampleDarkPrimaryLow : sampleLightAccentTint,
    onTertiaryContainer: onContainer,
    surface: surface,
    onSurface: text,
    onSurfaceVariant: secondary,
    surfaceTint: Colors.transparent,
    surfaceDim: dark ? sampleDarkSurface : surface2,
    surfaceBright: dark ? sampleDarkHover : surface,
    surfaceContainerLowest: dark ? sampleDarkSurface : surface,
    surfaceContainerLow: surface,
    surfaceContainer: surface2,
    surfaceContainerHigh: surface,
    surfaceContainerHighest: surface2,
    outline: sampleControlOutlineFor(brightness),
    outlineVariant: dark ? sampleDarkDivider : sampleLightHairline,
    error: sampleDangerFor(brightness),
    onError: dark ? sampleDarkOnError : sampleTint,
    errorContainer: dark ? sampleDarkDangerTint : sampleDangerTint,
    onErrorContainer: sampleDangerFor(brightness),
    inverseSurface: dark ? sampleDarkText : sampleNavy,
    onInverseSurface: dark ? sampleDarkSurface : sampleTint,
  );
  final typography = SampleTypography.textTheme.apply(
    bodyColor: text,
    displayColor: text,
  );
  final appBarSurface = dark ? sampleDarkSurface : sampleLightBackground;
  final appBarText = text;
  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(SampleRadius.md),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? sampleDarkSurface : sampleLightBackground,
    textTheme: typography.copyWith(
      bodySmall: typography.bodySmall?.copyWith(color: secondary),
      labelSmall: typography.labelSmall?.copyWith(color: secondary),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: accent,
      selectionHandleColor: accent,
      selectionColor: accent.withValues(alpha: 0.2),
    ),
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: appBarText,
      systemOverlayStyle: sampleSystemBarStyle(appBarSurface),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: typography.titleLarge?.copyWith(color: appBarText),
      iconTheme: IconThemeData(color: appBarText),
      actionsIconTheme: IconThemeData(color: appBarText),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: button,
        foregroundColor: sampleTint,
        minimumSize: const Size(SampleSize.touchMin, SampleSize.touchMin),
        padding: const EdgeInsets.symmetric(
          horizontal: SampleSpacing.space6,
          vertical: SampleSpacing.space3,
        ),
        shape: const StadiumBorder(),
        textStyle: SampleTypography.buttonLabel,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: text,
        side: BorderSide(
          color: scheme.outline,
          width: sampleOutlineWidthFor(brightness),
        ),
        minimumSize: const Size(SampleSize.touchMin, SampleSize.touchMin),
        padding: const EdgeInsets.symmetric(
          horizontal: SampleSpacing.space6,
          vertical: SampleSpacing.space3,
        ),
        shape: const StadiumBorder(),
        textStyle: SampleTypography.buttonLabel,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        minimumSize: const Size(SampleSize.touchMin, SampleSize.touchMin),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(SampleSize.touchMin, SampleSize.touchMin),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: WidgetStateTextStyle.resolveWith(
        (states) => typography.bodyLarge!.copyWith(
          color: states.contains(WidgetState.disabled)
              ? secondary
              : states.contains(WidgetState.error)
              ? scheme.error
              : states.contains(WidgetState.focused)
              ? accent
              : secondary,
        ),
      ),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) => typography.bodyLarge!.copyWith(
          color: states.contains(WidgetState.disabled)
              ? secondary
              : states.contains(WidgetState.error)
              ? scheme.error
              : states.contains(WidgetState.focused)
              ? accent
              : secondary,
        ),
      ),
      hintStyle: typography.bodyLarge?.copyWith(color: secondary),
      filled: false,
      contentPadding: const EdgeInsets.all(SampleSpacing.space4),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SampleRadius.md),
        borderSide: BorderSide(
          color: scheme.outline,
          width: sampleOutlineWidthFor(brightness),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SampleRadius.md),
        borderSide: BorderSide(color: accent, width: 2),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? sampleOnControlAccent(brightness)
            : scheme.outline,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? sampleControlAccent(brightness)
            : surface2,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? sampleControlAccent(brightness)
            : scheme.outline,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? button : null,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.white),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? accent : scheme.outline,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, SampleSize.touchMin)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? container
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? onContainer : text,
        ),
        side: WidgetStatePropertyAll(
          BorderSide(
            color: scheme.outline,
            width: sampleOutlineWidthFor(brightness),
          ),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: container,
      labelStyle: typography.labelMedium?.copyWith(color: text),
      secondaryLabelStyle: typography.labelMedium?.copyWith(color: onContainer),
      checkmarkColor: onContainer,
      deleteIconColor: secondary,
      side: WidgetStateBorderSide.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.selected)
              ? Colors.transparent
              : scheme.outline,
          width: sampleOutlineWidthFor(brightness),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface2,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: container,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => typography.labelMedium?.copyWith(
          color: states.contains(WidgetState.selected) ? text : secondary,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? onContainer
              : secondary,
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      minTileHeight: SampleSize.rowMin,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: SampleSpacing.space4,
        vertical: SampleSpacing.space2,
      ),
      textColor: text,
      iconColor: text,
      subtitleTextStyle: typography.bodySmall?.copyWith(color: secondary),
    ),
    hoverColor: dark ? sampleDarkHover : sampleLightAccentTint,
    highlightColor: accent.withValues(alpha: 0.12),
    splashColor: accent.withValues(alpha: 0.12),
    dividerColor: scheme.outlineVariant,
    cardTheme: CardThemeData(
      color: surface,
      shape: controlShape.copyWith(
        side: BorderSide(
          color: sampleBorderFor(brightness),
          width: sampleOutlineWidthFor(brightness),
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      modalBackgroundColor: surface,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: sampleSnackBarBackgroundFor(brightness),
      contentTextStyle: typography.bodyMedium?.copyWith(
        color: sampleSnackBarContentFor(brightness),
      ),
      actionTextColor: sampleSnackBarActionFor(brightness),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
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
/// Dark colors share the Signal constants with the shell; see `design.dart`
/// for the mapping and the roles the Flutter SDK cannot override.
const Color _sdkPrimaryMainLight = sampleNavy;
const Color _sdkPrimaryLowLight = sampleLightAccentContainer;
const Color _sdkPrimaryHighLight = sampleAccentBlue;
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
const Color _sampleBackground = sampleDemoBackground;

/// Deliberately loud link color, same reasoning as [_sampleBackground].
// off-table: deliberate SDK link override for the theme scenario
const Color _sampleLink = sampleDemoLink;

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
