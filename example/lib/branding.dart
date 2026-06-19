import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

/// Octopus brand palette used by the sample's own Material chrome.
const Color octopusTeal = Color(0xFF024C5B);
const Color octopusSalmon = Color(0xFFF49C8E);

/// Builds the sample app's Material 3 theme for the given [brightness].
ThemeData buildAppTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: octopusTeal,
    brightness: brightness,
  ).copyWith(secondary: octopusSalmon);
  return ThemeData(useMaterial3: true, colorScheme: scheme);
}

/// Builds the custom [OctopusTheme] showcased by the Theme scenario:
/// brand colors + the bundled logo.
///
/// Intentionally leaves [OctopusTheme.themeMode] unset. The consuming layer
/// ([AppState.effectiveOctopusTheme]) applies the host's Light/Dark/System
/// choice, so the brand colors render against the matching surface and the
/// Config screen's theme picker stays the single source of truth for
/// light/dark across both the Flutter chrome AND the SDK content.
OctopusTheme brandOctopusTheme(String? logoBase64) {
  return OctopusTheme(
    primaryMain: octopusTeal,
    primaryLowContrast: octopusTeal.withValues(alpha: 0.15),
    primaryHighContrast: octopusSalmon,
    onPrimary: Colors.white,
    logoBase64: logoBase64,
  );
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
