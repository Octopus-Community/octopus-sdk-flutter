import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../auth/login_page.dart';
import '../auth/profile_edit_page.dart';
import '../config/config_screen.dart';
import '../design.dart';
import '../settings/account_screen.dart';
import 'client_profile_page.dart';

/// Community tab — the SDK's own embedded UI ([OctopusHomeScreen]).
///
/// Reflects the active custom theme (Theme scenario), the locale override
/// (Locale scenario), and any push deep-link (Community deep-link). A
/// [ValueKey] derived from those forces a fresh PlatformView when they change,
/// because UiKitView/AndroidView ignore creationParams changes after mount.
class CommunityTab extends StatelessWidget {
  const CommunityTab({super.key});

  /// Blocking band action — retries the initialisation with the setup already
  /// saved, or sends the host back to Config when there is nothing to retry.
  Future<void> _retry(BuildContext context) async {
    final app = AppScope.of(context);
    final config = app.config;
    if (config == null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const ConfigScreen(entry: ConfigEntry.revisit),
        ),
      );
      return;
    }
    await app.start(config);
  }

  /// Degraded band action — Settings → Account, where the SSO user connects.
  void _connect(BuildContext context) {
    AppScope.of(context).requestTab(3);
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute<void>(builder: (_) => const AccountScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);

    if (!app.initialized) {
      // Not initialised covers two very different states, and only one of them
      // is a problem: a cold start still in flight, and an initialisation that
      // actually failed. Band A is blocking and accusatory ("check your API
      // key"), so it is keyed on the recorded error — never on the normal
      // second or two the first Start takes.
      final failed = app.initError != null;
      return Column(
        children: [
          if (failed)
            SampleBand(
              tone: SampleTone.danger,
              message:
                  "Couldn't reach the community — Check the server and API key "
                  'in Config.',
              actionLabel: 'Retry',
              onAction: () => _retry(context),
              identifier: 'community-band-blocked',
            ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: failed
                      ? const [
                          Icon(Icons.cloud_off, size: 56),
                          SizedBox(height: 12),
                          Text(
                            'The community loads once the SDK is initialised.',
                            textAlign: TextAlign.center,
                          ),
                        ]
                      : const [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Starting the SDK…',
                            textAlign: TextAlign.center,
                          ),
                        ],
                ),
              ),
            ),
          ),
        ],
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
    // Band B — degraded. The sample layer sits ABOVE the SDK surface; the SDK
    // surface itself never carries sample chrome.
    return Column(
      children: [
        if (!app.userConnected)
          SampleBand(
            tone: SampleTone.warning,
            message: 'Read-only — Connect an SSO user to post and react.',
            actionLabel: 'Connect',
            onAction: () => _connect(context),
            identifier: 'community-band-readonly',
          ),
        Expanded(child: _octopusHome(context, app, key, octopusTheme, pending)),
      ],
    );
  }

  Widget _octopusHome(
    BuildContext context,
    AppState app,
    Key key,
    OctopusTheme? octopusTheme,
    OctopusNotification? pending,
  ) {
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
