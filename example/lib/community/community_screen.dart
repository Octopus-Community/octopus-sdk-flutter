import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../auth/login_page.dart';
import '../auth/profile_edit_page.dart';
import 'client_profile_page.dart';

/// Community tab — the SDK's own embedded UI ([OctopusHomeScreen]).
///
/// Reflects the active custom theme (Theme scenario), the locale override
/// (Locale scenario), and any push deep-link (Community deep-link). A
/// [ValueKey] derived from those forces a fresh PlatformView when they change,
/// because UiKitView/AndroidView ignore creationParams changes after mount.
class CommunityTab extends StatelessWidget {
  const CommunityTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);

    if (!app.initialized) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 56),
              SizedBox(height: 12),
              Text(
                'SDK not initialized. Check the Home tab for the init status.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final pending = app.pendingCommunityNotification;
    final octopusTheme = app.effectiveOctopusTheme();
    final key = ValueKey<String>(
      'community'
      '|${pending?.linkPath ?? 'root'}'
      '|${app.activeThemeLabel}'
      '|${app.localeChoice.name}'
      // Include the resolved SDK theme mode so a Config-screen Light/Dark
      // change forces a fresh PlatformView (creationParams are read once
      // at mount). Today the host returns to Config to flip themes, so
      // this is defensive — but it costs nothing and keeps the contract
      // honest if Settings ever gains a live theme toggle.
      '|${octopusTheme?.themeMode?.name ?? 'sdkDefault'}'
      // The Unified Profile switch is mount-time (it rides in creationParams),
      // so flipping it must remount the PlatformView — otherwise the toggle
      // silently does nothing until the tab happens to rebuild.
      '|${app.unifiedProfileWired ? 'profileWired' : 'profileNative'}',
    );

    // Embedded mode: the SDK renders its own native top bar (the M3
    // `OctopusTopAppBar` on Android, `UINavigationBar` on iOS) for BOTH the
    // home and any deeper screen the user navigates into (post detail,
    // group detail, …). The host Flutter shell drops its own `AppBar` on
    // the Community tab (see `main.dart`) so the two never stack.
    //
    // `OctopusHomeContent` (no-navbar variant) is intentionally NOT used
    // here yet — it removes the top bar on the home only, leaving every
    // deeper SDK screen still rendering its own native toolbar, which
    // produces a host-AppBar + native-toolbar double header in nav-deep
    // states. Until iOS ships its `OctopusHomeContent` equivalent
    // (tracked internally), staying on `OctopusHomeScreen` on
    // BOTH platforms keeps the two natives visually aligned in the sample.
    // The non-embedded integration modes (Modal / Fullscreen / Sheet) are
    // demonstrated by their respective scenarios in the Scenarios tab.
    return OctopusHomeScreen(
      key: key,
      theme: octopusTheme,
      // Match the Flutter shell's other-tab titles so switching between
      // Home / Scenarios / Community / Settings doesn't reveal a sudden
      // branding change. The SDK renders "Community" in its own native
      // top bar; with `navBarPrimaryColor: false` the SDK uses its default
      // light/white surface with dark text — closer to the Material AppBar
      // the host renders on the other tabs (white surface, dark title).
      // Flip to `true` to demo the brand-primary-tinted top bar.
      navBarTitle: 'Community',
      navBarPrimaryColor: false,
      // Center the "Community" title in the top bar **on iOS only** — that
      // matches the platform conventions: iOS `UINavigationBar` titles are
      // centered, Android Material 3 top-app-bar titles stay leading. The
      // param works on both platforms (Android `titleCentered`, iOS
      // `OctopusMainFeedTitle.Placement.center`); here the sample opts into
      // centering only where it's the native look.
      titleCentered: Theme.of(context).platform == TargetPlatform.iOS,
      showBackButton: false,
      notification: pending,
      onNavigateToLogin: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const LoginPage())),
      onModifyUser: (field) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProfileEditPage(fieldToEdit: field)),
      ),
      onNavigateToUrl: (url) {
        demoLog.apiCall('onNavigateToUrl', {'url': url});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Navigate to URL (handled by app): $url')),
        );
        return UrlOpeningStrategy.handledByApp;
      },
      // Unified Profile. Passing this callback is the activation switch: the SDK
      // then routes EVERY profile tap here — the connected user's own included —
      // and stops showing its native profile screens. Wired only when the
      // Settings toggle is on, so the sample demonstrates both behaviours; a
      // real host would simply always pass it (or never).
      //
      // Nothing changes unless the community also exposes client user ids: until
      // then the SDK keeps its own screens and this is never called.
      onNavigateToProfile: app.unifiedProfileWired
          ? (clientUserId) {
              demoLog.apiCall('onNavigateToProfile', {
                'clientUserId': clientUserId,
              });
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ClientProfilePage(clientUserId: clientUserId),
                ),
              );
            }
          : null,
    );
  }
}
