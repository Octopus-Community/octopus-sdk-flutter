import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_scaffold.dart';

/// Refresh entitlements scenario — `refreshEntitlements` returning a typed
/// [OctopusResult] + a live view of the current [OctopusProfile.entitlements].
///
/// Mints a fresh JWT for the connected user and re-applies its claims. The
/// resulting set is surfaced through the `profile` stream — the live-state card
/// reads `app.profile?.entitlements` so a successful refresh is visible
/// immediately. Failures are pattern-matched onto the typed
/// [RefreshEntitlementsError] subtypes.
class RefreshEntitlementsScenario extends StatelessWidget {
  const RefreshEntitlementsScenario({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final entitlements = app.profile?.entitlements ?? const <String>{};
    final entitlementsLabel = app.profile == null
        ? '— (no profile)'
        : entitlements.isEmpty
        ? '— (empty set)'
        : entitlements.join(', ');

    return ScenarioScaffold(
      title: 'Refresh entitlements',
      description:
          'Calls refreshEntitlements() to mint a fresh JWT and re-apply its '
          'claims. On success the OctopusProfile.entitlements set below is '
          'updated through the profile stream. Failures are decoded into the '
          'typed RefreshEntitlementsError subtypes.',
      resultTestId: 'refresh-entitlements-result',
      liveState: KeyValueCard(
        title: 'Live state',
        rows: [('Entitlements', entitlementsLabel)],
      ),
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-refresh-entitlements-1',
          label: 'Preset 1 · Refresh entitlements',
          onRun: (setResult) async {
            try {
              demoLog.apiCall('refreshEntitlements');
              final result = await app.octopus.refreshEntitlements();
              switch (result) {
                case OctopusSuccess():
                  final fresh = app.profile?.entitlements ?? const <String>{};
                  final freshLabel = fresh.isEmpty
                      ? '<empty set>'
                      : fresh.join(', ');
                  setResult(
                    'refreshEntitlements succeeded. '
                    'Current entitlements: $freshLabel.',
                  );
                case OctopusInvalidArguments<OctopusServerError>(:final errors):
                  // Typed-error path: pattern-match every known subtype so
                  // the automated UI tests see which branch fired. The outer
                  // `<OctopusServerError>` annotation is required for
                  // exhaustiveness (see OctopusResult dartdoc); narrow back
                  // to the method's typed error here.
                  final labels = errors
                      .cast<RefreshEntitlementsError>()
                      .map((error) {
                        final label = switch (error) {
                          RefreshEntitlementsNoClientTokenProviderError() =>
                            'NoClientTokenProvider',
                          RefreshEntitlementsUserNotConnectedError() =>
                            'UserNotConnected',
                          RefreshEntitlementsNoNetworkError() => 'NoNetwork',
                          RefreshEntitlementsUserBannedError() => 'UserBanned',
                          RefreshEntitlementsServerError() => 'ServerError',
                        };
                        return 'RefreshEntitlements$label: $error';
                      })
                      .join(', ');
                  setResult(
                    'refreshEntitlements failed with $labels.',
                    isError: true,
                  );
                case OctopusConnectionFailure():
                  // Connection-level failures (no typed error).
                  setResult(
                    'refreshEntitlements failed at the connection layer: '
                    '$result.',
                    isError: true,
                  );
              }
            } catch (e) {
              setResult('refreshEntitlements threw: $e', isError: true);
            }
          },
        ),
      ],
    );
  }
}
