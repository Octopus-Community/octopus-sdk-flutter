import 'dart:ui' show Color;

/// Enum for theme mode options
enum OctopusThemeMode {
  /// Light theme mode
  light,

  /// Dark theme mode
  dark,
}

/// Class to customize the appearance of the Octopus interface
///
/// Allows customization of colors, font sizes and other visual aspects
/// of the Octopus Community interface.
///
/// **Every field is optional, and `null` means "keep the native default".** No
/// slot is ever substituted by the bridge: setting [background] alone leaves the
/// primary palette, the logo and all seven font sizes on their native values.
/// Both SDKs ship the same default type scale (26 / 22 / 18 / 16 / 14 / 12
/// points), and a size you set here is a *base* size on both platforms, not a
/// frozen one: Android resolves it as `sp` and iOS runs it through
/// `UIFontMetrics`, so the rendered text still follows the reader's system
/// font-size setting. Leaving a slot unset keeps the native default, which
/// scales the same way.
///
/// Complete usage example:
///
/// ```dart
/// final theme = OctopusTheme(
///   // Colors
///   primaryMain: const Color(0xFF6200EA),
///   primaryLowContrast: const Color(0xFF6200EA).withOpacity(0.2),
///   primaryHighContrast: Colors.white,
///   onPrimary: Colors.white,
///   background: const Color(0xFF101014),
///   link: const Color(0xFF1D9BD1),
///
///   // Font sizes, in points — omit a slot to keep the native default
///   fontSizeTitle1: 24,
///   fontSizeTitle2: 20,
///   fontSizeBody1: 16,
///   fontSizeBody2: 14,
///   fontSizeCaption1: 13,
///   fontSizeCaption2: 11,
///   fontSizeNavBarItem: 16,
///
///   // Custom logo (base64)
///   logoBase64: '...',
///
///   // Theme mode
///   themeMode: OctopusThemeMode.dark,
/// );
///
/// // Usage with showNativeUI
/// await octopus.showNativeUI(
///   navBarTitle: 'My App',
///   navBarPrimaryColor: true,
///   theme: theme,
/// );
///
/// // Or usage with embeddedView
/// OctopusSDK.embeddedView(
///   navBarTitle: 'My App',
///   theme: theme,
/// )
/// ```
class OctopusTheme {
  /// Main interface color
  final Color? primaryMain;

  /// Main color with low contrast (usually with transparency)
  final Color? primaryLowContrast;

  /// Main color with high contrast
  final Color? primaryHighContrast;

  /// Content color displayed on the primary color
  final Color? onPrimary;

  /// Background color of the community screens.
  ///
  /// When left `null` the native default applies: the light/dark surface
  /// resolved from [themeMode] on Android (`OctopusColorScheme.background`)
  /// and the system background on iOS.
  ///
  /// On Android this also drives the embedded top app bar's container color
  /// whenever `navBarPrimaryColor` is `false`, since that bar tracks the
  /// resolved scheme's background.
  final Color? background;

  /// Color of links rendered inside posts and comments (URLs, mentions).
  ///
  /// When left `null` the native default applies on both platforms.
  final Color? link;

  /// Custom font family applied to all SDK text (titles, body text,
  /// captions, and navigation bar items — see the per-platform navigation
  /// bar note below).
  ///
  /// This name is **not** resolved from the Flutter asset bundle: a font
  /// declared under `flutter: fonts:` in `pubspec.yaml` lives only inside
  /// the Flutter engine's own asset manager, which neither native SDK can
  /// read. Both native SDKs render their screens as real platform views
  /// (Compose on Android, SwiftUI on iOS), so the font must additionally be
  /// registered as a **native** resource in the host app, using this exact
  /// name:
  ///
  /// - **Android**: the resource name of a font file, or an XML
  ///   `<font-family>`, placed under `android/app/src/main/res/font/` in
  ///   the host app — e.g. `res/font/my_brand_font.ttf` is passed as
  ///   `'my_brand_font'` (resource names are lowercase with underscores
  ///   only, no extension). If no matching resource is found, the SDK logs
  ///   a warning and keeps its own default font.
  /// - **iOS**: the exact PostScript name of a font added to the Xcode
  ///   project and declared under `UIAppFonts` in
  ///   `ios/Runner/Info.plist`. If the name does not resolve to a
  ///   registered font, the SDK logs a warning and keeps its own default
  ///   font.
  ///
  /// Navigation bar scope differs by platform: on Android this only
  /// restyles the top app bar's title text (the native back/close controls
  /// are icons, not text, so they have no font to override); on iOS it also
  /// applies to the navigation bar's icon buttons, whose SF Symbols scale
  /// with the font.
  ///
  /// Setting this (or [fontWeight]) also sets the Android navigation bar
  /// title to the size of [fontSizeBody1], which is smaller than the title
  /// size used when no font override is set. Use [fontSizeBody1] to control
  /// the resulting size.
  ///
  /// Default: `null`, which keeps each native SDK's own default font.
  final String? fontFamily;

  /// Custom font weight applied to all SDK text (titles, body text,
  /// captions, and navigation bar items), on a 100 (thinnest) - 900
  /// (boldest) scale — the same scale as CSS `font-weight` and Android's
  /// `FontWeight`. Unlike [fontFamily], this needs no native registration:
  /// it is applied on top of whichever font family is in effect (custom or
  /// default), and native rendering picks the closest weight the font
  /// actually has a face for.
  ///
  /// Must be within 100-900 when set; the constructor asserts this. Note that
  /// this is Flutter's `FontWeight.value`, not its `index` — `FontWeight.w100`
  /// has `index == 0`, so mapping from `index` produces an invalid weight.
  ///
  /// Setting this also sets the Android navigation bar title to the size of
  /// [fontSizeBody1], exactly as [fontFamily] does.
  ///
  /// Default: `null`, which keeps each native SDK's own default weight.
  final int? fontWeight;

  /// Font size for main titles, in points. Native default: 26.
  final int? fontSizeTitle1;

  /// Font size for secondary titles, in points. Native default: 22.
  final int? fontSizeTitle2;

  /// Font size for main body text, in points. Native default: 18.
  final int? fontSizeBody1;

  /// Font size for secondary body text, in points. Native default: 16.
  final int? fontSizeBody2;

  /// Font size for main captions, in points. Native default: 14.
  final int? fontSizeCaption1;

  /// Font size for secondary captions, in points. Native default: 12.
  final int? fontSizeCaption2;

  /// Font size for navigation-bar items (back / close labels, bar actions).
  ///
  /// **iOS only.** This key has no effect on Android: the native iOS theme
  /// has a dedicated `navBarItem` font slot, but the native Android
  /// typography has no counterpart, so the Android bridge ignores it.
  ///
  /// When left `null` the bridge keeps its long-standing iOS behaviour: nav-bar
  /// items follow [fontSizeBody1]. With *both* left `null`, the native default
  /// stands (the system `.body` font, which is not the same size as the
  /// `body1` default).
  final int? fontSizeNavBarItem;

  /// Custom logo encoded in base64
  /// Format: 'iVBORw0KGgoAAAANSUhEUgAA...'
  final String? logoBase64;

  /// Theme mode (light or dark)
  final OctopusThemeMode? themeMode;

  const OctopusTheme({
    this.primaryMain,
    this.primaryLowContrast,
    this.primaryHighContrast,
    this.onPrimary,
    this.background,
    this.link,
    this.fontFamily,
    this.fontWeight,
    this.fontSizeTitle1,
    this.fontSizeTitle2,
    this.fontSizeBody1,
    this.fontSizeBody2,
    this.fontSizeCaption1,
    this.fontSizeCaption2,
    this.fontSizeNavBarItem,
    this.logoBase64,
    this.themeMode,
  }) : assert(
          fontWeight == null || (fontWeight >= 100 && fontWeight <= 900),
          'fontWeight must be within 100-900, got $fontWeight. '
          'Pass a FontWeight.value (w100 == 100), not a FontWeight.index '
          '(w100.index == 0).',
        );

  /// Creates a copy of the theme with modified parameters
  OctopusTheme copyWith({
    Color? primaryMain,
    Color? primaryLowContrast,
    Color? primaryHighContrast,
    Color? onPrimary,
    Color? background,
    Color? link,
    String? fontFamily,
    int? fontWeight,
    int? fontSizeTitle1,
    int? fontSizeTitle2,
    int? fontSizeBody1,
    int? fontSizeBody2,
    int? fontSizeCaption1,
    int? fontSizeCaption2,
    int? fontSizeNavBarItem,
    String? logoBase64,
    OctopusThemeMode? themeMode,
  }) {
    return OctopusTheme(
      primaryMain: primaryMain ?? this.primaryMain,
      primaryLowContrast: primaryLowContrast ?? this.primaryLowContrast,
      primaryHighContrast: primaryHighContrast ?? this.primaryHighContrast,
      onPrimary: onPrimary ?? this.onPrimary,
      background: background ?? this.background,
      link: link ?? this.link,
      fontFamily: fontFamily ?? this.fontFamily,
      fontWeight: fontWeight ?? this.fontWeight,
      fontSizeTitle1: fontSizeTitle1 ?? this.fontSizeTitle1,
      fontSizeTitle2: fontSizeTitle2 ?? this.fontSizeTitle2,
      fontSizeBody1: fontSizeBody1 ?? this.fontSizeBody1,
      fontSizeBody2: fontSizeBody2 ?? this.fontSizeBody2,
      fontSizeCaption1: fontSizeCaption1 ?? this.fontSizeCaption1,
      fontSizeCaption2: fontSizeCaption2 ?? this.fontSizeCaption2,
      fontSizeNavBarItem: fontSizeNavBarItem ?? this.fontSizeNavBarItem,
      logoBase64: logoBase64 ?? this.logoBase64,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  /// Converts the theme to a Map for transmission to native platforms
  Map<String, dynamic> toMap() {
    return {
      if (primaryMain != null) 'primaryMain': primaryMain!.toARGB32(),
      if (primaryLowContrast != null)
        'primaryLowContrast': primaryLowContrast!.toARGB32(),
      if (primaryHighContrast != null)
        'primaryHighContrast': primaryHighContrast!.toARGB32(),
      if (onPrimary != null) 'onPrimary': onPrimary!.toARGB32(),
      if (background != null) 'background': background!.toARGB32(),
      if (link != null) 'link': link!.toARGB32(),
      if (fontFamily != null) 'fontFamily': fontFamily,
      if (fontWeight != null) 'fontWeight': fontWeight,
      if (fontSizeTitle1 != null) 'fontSizeTitle1': fontSizeTitle1,
      if (fontSizeTitle2 != null) 'fontSizeTitle2': fontSizeTitle2,
      if (fontSizeBody1 != null) 'fontSizeBody1': fontSizeBody1,
      if (fontSizeBody2 != null) 'fontSizeBody2': fontSizeBody2,
      if (fontSizeCaption1 != null) 'fontSizeCaption1': fontSizeCaption1,
      if (fontSizeCaption2 != null) 'fontSizeCaption2': fontSizeCaption2,
      if (fontSizeNavBarItem != null) 'fontSizeNavBarItem': fontSizeNavBarItem,
      if (logoBase64 != null) 'logoBase64': logoBase64,
      if (themeMode != null) 'themeMode': themeMode!.name,
    };
  }
}
