import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// System icons contrast with the surface painted underneath each bar.
SystemUiOverlayStyle sampleSystemBarStyle(Color surface) {
  final brightness = ThemeData.estimateBrightnessForColor(surface);
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: brightness,
    statusBarIconBrightness: brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark,
    systemNavigationBarColor: surface,
    systemNavigationBarIconBrightness: brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  );
}

/// Fallback for routes without an AppBar; owns no padding or safe-area inset.
/// AppBars override the top region and the tab bar overrides the bottom one.
class SampleSystemBars extends StatelessWidget {
  const SampleSystemBars({super.key, this.surface, required this.child});

  final Color? surface;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: sampleSystemBarStyle(
      surface ?? Theme.of(context).scaffoldBackgroundColor,
    ),
    child: child,
  );
}
