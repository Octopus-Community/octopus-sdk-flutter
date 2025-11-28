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
/// Complete usage example:
/// 
/// ```dart
/// final theme = OctopusTheme(
///   // Colors
///   primaryMain: const Color(0xFF6200EA),
///   primaryLowContrast: const Color(0xFF6200EA).withOpacity(0.2),
///   primaryHighContrast: Colors.white,
///   onPrimary: Colors.white,
///   
///   // Font sizes (in points)
///   fontSizeTitle1: 26,
///   fontSizeTitle2: 20,
///   fontSizeBody1: 17,
///   fontSizeBody2: 14,
///   fontSizeCaption1: 12,
///   fontSizeCaption2: 10,
///   
///   // Custom logo (base64)
///   logoBase64: 'data:image/png;base64,...',
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
/// OctopusSdkFlutter.embeddedView(
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
  
  /// Font size for main titles (default: 26)
  final int? fontSizeTitle1;
  
  /// Font size for secondary titles (default: 20)
  final int? fontSizeTitle2;
  
  /// Font size for main body text (default: 17)
  final int? fontSizeBody1;
  
  /// Font size for secondary body text (default: 14)
  final int? fontSizeBody2;
  
  /// Font size for main captions (default: 12)
  final int? fontSizeCaption1;
  
  /// Font size for secondary captions (default: 10)
  final int? fontSizeCaption2;
  
  /// Custom logo encoded in base64
  /// Format: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...'
  /// or simply the base64 string without the prefix
  final String? logoBase64;
  
  /// Theme mode (light or dark)
  final OctopusThemeMode? themeMode;

  const OctopusTheme({
    this.primaryMain,
    this.primaryLowContrast,
    this.primaryHighContrast,
    this.onPrimary,
    this.fontSizeTitle1,
    this.fontSizeTitle2,
    this.fontSizeBody1,
    this.fontSizeBody2,
    this.fontSizeCaption1,
    this.fontSizeCaption2,
    this.logoBase64,
    this.themeMode,
  });

  /// Creates a copy of the theme with modified parameters
  OctopusTheme copyWith({
    Color? primaryMain,
    Color? primaryLowContrast,
    Color? primaryHighContrast,
    Color? onPrimary,
    int? fontSizeTitle1,
    int? fontSizeTitle2,
    int? fontSizeBody1,
    int? fontSizeBody2,
    int? fontSizeCaption1,
    int? fontSizeCaption2,
    String? logoBase64,
    OctopusThemeMode? themeMode,
  }) {
    return OctopusTheme(
      primaryMain: primaryMain ?? this.primaryMain,
      primaryLowContrast: primaryLowContrast ?? this.primaryLowContrast,
      primaryHighContrast: primaryHighContrast ?? this.primaryHighContrast,
      onPrimary: onPrimary ?? this.onPrimary,
      fontSizeTitle1: fontSizeTitle1 ?? this.fontSizeTitle1,
      fontSizeTitle2: fontSizeTitle2 ?? this.fontSizeTitle2,
      fontSizeBody1: fontSizeBody1 ?? this.fontSizeBody1,
      fontSizeBody2: fontSizeBody2 ?? this.fontSizeBody2,
      fontSizeCaption1: fontSizeCaption1 ?? this.fontSizeCaption1,
      fontSizeCaption2: fontSizeCaption2 ?? this.fontSizeCaption2,
      logoBase64: logoBase64 ?? this.logoBase64,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  /// Converts the theme to a Map for transmission to native platforms
  Map<String, dynamic> toMap() {
    return {
      if (primaryMain != null) 'primaryMain': primaryMain!.value,
      if (primaryLowContrast != null) 'primaryLowContrast': primaryLowContrast!.value,
      if (primaryHighContrast != null) 'primaryHighContrast': primaryHighContrast!.value,
      if (onPrimary != null) 'onPrimary': onPrimary!.value,
      if (fontSizeTitle1 != null) 'fontSizeTitle1': fontSizeTitle1,
      if (fontSizeTitle2 != null) 'fontSizeTitle2': fontSizeTitle2,
      if (fontSizeBody1 != null) 'fontSizeBody1': fontSizeBody1,
      if (fontSizeBody2 != null) 'fontSizeBody2': fontSizeBody2,
      if (fontSizeCaption1 != null) 'fontSizeCaption1': fontSizeCaption1,
      if (fontSizeCaption2 != null) 'fontSizeCaption2': fontSizeCaption2,
      if (logoBase64 != null) 'logoBase64': logoBase64,
      if (themeMode != null) 'themeMode': themeMode!.name,
    };
  }
}