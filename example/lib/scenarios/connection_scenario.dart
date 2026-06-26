import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_state.dart';
import '../octopus_demo_config.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_scaffold.dart';

/// Connection scenario — `connectUser` / `disconnectUser`.
class ConnectionScenario extends StatelessWidget {
  const ConnectionScenario({super.key});

  /// Granular label for the current connection state.
  ///
  /// Distinguishes a real connected user from an anonymous **guest** session
  /// (the SDK auto-establishes a guest after `disconnectUser` on a
  /// forced-login community). **Platform note:** only Android reports
  /// `OctopusConnected.isGuest`; iOS never sets it (the public iOS SDK has no
  /// guest indicator — tracked for the native team), so on iOS a guest reads
  /// as plain "connected".
  static String _connectionLabel(OctopusConnectionState? state) =>
      switch (state) {
        OctopusConnected(isGuest: true) => 'connected · guest',
        OctopusConnected() => 'connected',
        _ => 'anonymous',
      };

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ScenarioScaffold(
      title: 'Connection',
      description:
          'Connect the bundled demo SSO user with a **persistent** token '
          'provider (so refreshEntitlements works) and pick which '
          'entitlements the host signs into the user JWT. Presets 1–4 each '
          'connect with a different requested entitlement set; the BE '
          'validates them, and the SDK\'s OctopusProfile.entitlements '
          'stream reflects the resolved set in the Live state below. '
          'Requires --dart-define=OCTOPUS_SSO_CLIENT_USER_TOKEN_SECRET '
          '(`--dart-define` injects it). Without it, the sample '
          'falls back to the pre-baked OCTOPUS_USER_TOKEN — connect still '
          'works but refreshEntitlements returns NoClientTokenProvider.\n\n'
          'After Disconnect, a forced-login community re-establishes a '
          'guest session — Android shows it as "connected · guest", iOS '
          'as plain "connected" (iOS exposes no guest flag yet).',
      resultTestId: 'connection-result',
      liveState: KeyValueCard(
        title: 'Live state',
        rows: [
          ('Connection', _connectionLabel(app.connectionState)),
          ('User id', app.effectiveUserId),
          ('User token', hasInjectedUserToken ? 'injected' : 'not injected'),
          (
            'SSO secret (for refresh)',
            hasInjectedSsoSecret ? 'injected' : 'not injected',
          ),
          (
            'Requested entitlements',
            app.currentEntitlements.isEmpty
                ? '— (none)'
                : (app.currentEntitlements.toList()..sort()).join(', '),
          ),
          (
            'SDK profile entitlements',
            app.profile == null
                ? '— (no profile)'
                : app.profile!.entitlements.isEmpty
                ? '— (empty set)'
                : (app.profile!.entitlements.toList()..sort()).join(', '),
          ),
        ],
      ),
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-connection-1',
          label: 'Preset 1 · Connect (no entitlements)',
          onRun: (setResult) async {
            final userId = app.effectiveUserId;
            try {
              await app.connectDemoUser(entitlements: const {});
              setResult(
                'connectUser("$userId") done with no entitlements — '
                'see Live state.',
              );
            } catch (e) {
              setResult('connectUser failed: $e', isError: true);
            }
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-connection-2',
          label: 'Preset 2 · Connect as Premium',
          onRun: (setResult) async {
            final userId = app.effectiveUserId;
            try {
              await app.connectDemoUser(
                entitlements: const {'customer:premium'},
              );
              setResult(
                'connectUser("$userId") done with [customer:premium] '
                '— SDK profile entitlements (below) reflects the BE-resolved '
                'set after re-connect.',
              );
            } catch (e) {
              setResult('connectUser failed: $e', isError: true);
            }
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-connection-3',
          label: 'Preset 3 · Connect as Moderator',
          onRun: (setResult) async {
            final userId = app.effectiveUserId;
            try {
              await app.connectDemoUser(
                entitlements: const {'customer:moderator'},
              );
              setResult(
                'connectUser("$userId") done with [customer:moderator].',
              );
            } catch (e) {
              setResult('connectUser failed: $e', isError: true);
            }
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-connection-4',
          label: 'Preset 4 · Connect as Premium + Moderator',
          onRun: (setResult) async {
            final userId = app.effectiveUserId;
            try {
              await app.connectDemoUser(
                entitlements: const {'customer:premium', 'customer:moderator'},
              );
              setResult('connectUser("$userId") done with both entitlements.');
            } catch (e) {
              setResult('connectUser failed: $e', isError: true);
            }
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-connection-5',
          label: 'Preset 5 · Disconnect',
          onRun: (setResult) async {
            try {
              await app.disconnectUser();
              setResult(
                'disconnectUser done — see Live state (a forced-login '
                'community re-establishes a guest).',
              );
            } catch (e) {
              setResult('disconnectUser failed: $e', isError: true);
            }
          },
        ),
      ],
    );
  }
}
