import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_state.dart';
import '../config/config_screen.dart';
import '../design.dart';
import '../sample_tab.dart';
import '../settings/account_screen.dart';
import 'community_navigation.dart';
import 'present_community.dart';

/// Community tab — the SDK's own embedded UI ([OctopusHomeScreen]).
///
/// Reflects the active custom theme (Theme scenario), the locale override
/// (Locale scenario), and any push deep-link (Community deep-link). A
/// surface generation changes only when its mount-time inputs or navigation
/// target change; ordinary tab switches keep the PlatformView alive.
class CommunityTab extends StatelessWidget {
  const CommunityTab({super.key, this.active = true});

  final bool active;

  /// Blocking band action — retries the initialisation with the setup already
  /// saved, or sends the host back to Config when there is nothing to retry.
  Future<void> _retry(BuildContext context) async {
    final app = AppScope.of(context);
    final config = app.config;
    if (config == null) {
      await openConfigScreen(context, anchor: ConfigSection.community);
      return;
    }
    await app.start(config);
  }

  /// Degraded band action — Settings → Account, where the SSO user connects.
  void _connect(BuildContext context) {
    AppScope.of(context).requestTab(SampleTab.settings.index);
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
              // The message names Config, so the band leads there too — on
              // the Community section: the API key picker is the likelier
              // cause, and the Server section follows right below it.
              secondaryActionLabel: 'Config',
              onSecondaryAction: () =>
                  openConfigScreen(context, anchor: ConfigSection.community),
              secondaryActionIdentifier: 'community-band-config',
            ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(SampleSpacing.space8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: failed
                      ? const [
                          Icon(Icons.cloud_off, size: 56),
                          SizedBox(height: SampleSpacing.space3),
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
                          SizedBox(height: SampleSpacing.space3),
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
        Expanded(
          child: app.communityNavigation == CommunityNavigation.inTab
              ? (app.pendingCommunityNotification != null
                    ? const Center(child: CircularProgressIndicator())
                    : CommunitySurface(app: app, active: active))
              : const SizedBox.expand(),
        ),
      ],
    );
  }
}
