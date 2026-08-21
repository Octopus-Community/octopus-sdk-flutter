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
OctopusTheme surfaceOctopusTheme(String? logoBase64) {
  return brandOctopusTheme(logoBase64).copyWith(
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
