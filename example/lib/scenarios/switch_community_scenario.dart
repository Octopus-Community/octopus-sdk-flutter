import 'package:flutter/material.dart';
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../config/api_key_registry.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_scaffold.dart';

/// Switch Community scenario — exercises [OctopusSDK.switchCommunity] by
/// flipping between any of the build-time named API keys at runtime and
/// surfacing the SDK's initialisation + connection state on either side of
/// the call.
///
/// The presets enumerate the SAME named keys the Config screen shows in its
/// picker (`OCTOPUS_NAMED_API_KEYS` — `config/api_key_registry.dart`), so the
/// list is data-driven and no scenario edit is needed when adding a new named
/// key. A keyless / public build with no named keys gets no presets and an
/// inline note in the description.
///
/// iOS parity reference:
/// `Sample/OctopusSample/UI/Scenarios/SwitchCommunity/SwitchCommunityView.swift`.
class SwitchCommunityScenario extends StatelessWidget {
  const SwitchCommunityScenario({super.key});

  String _redactKey(String? key) {
    if (key == null || key.isEmpty) return '<empty>';
    final visible = key.length < 4 ? key : key.substring(0, 4);
    return '$visible…';
  }

  String _connectionLabel(OctopusConnectionState? state) {
    if (state == null) return '—';
    return switch (state) {
      OctopusNotConnected() => 'NotConnected',
      OctopusConnected(isGuest: final isGuest) =>
        'Connected(isGuest: $isGuest)',
    };
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final currentKey = app.activeApiKey;
    final hasNamedKeys = injectedApiKeys.isNotEmpty;
    return ScenarioScaffold(
      title: 'Switch community',
      description: hasNamedKeys
          ? 'Re-target the SDK at a different community at runtime via '
                'OctopusSDK.switchCommunity. The current API key, init flag, '
                'and connection state are shown below — they update as the '
                'SDK re-initialises against the new key. One preset per named '
                'key from the Config picker (--dart-define=OCTOPUS_NAMED_API_'
                'KEYS); pick the slot already active to re-init against the '
                'same community.'
          : 'Re-target the SDK at a different community at runtime via '
                'OctopusSDK.switchCommunity. This build ships no named keys '
                '(--dart-define=OCTOPUS_NAMED_API_KEYS is empty), so there is '
                'nothing to switch to. The build-time --dart-define injection '
                'launcher fills the named-key set from your secrets.',
      resultTestId: 'switch-community-result',
      liveState: KeyValueCard(
        title: 'Live state',
        rows: [
          ('Current API key', _redactKey(currentKey)),
          ('isInitialised', app.isInitialised.toString()),
          ('Connection state', _connectionLabel(app.connectionState)),
        ],
      ),
      presets: [
        for (var i = 0; i < injectedApiKeys.length; i++)
          ScenarioPreset(
            testId: 'qa-preset-switch-community-${injectedApiKeys[i].id}',
            label: 'Preset ${i + 1} · ${injectedApiKeys[i].label}',
            onRun: (setResult) async {
              final target = injectedApiKeys[i];
              try {
                demoLog.apiCall('switchCommunity', {
                  'slot': target.id,
                  'apiKey': _redactKey(target.key),
                  'appManagedFields': const <String>[],
                });
                await app.switchToCommunity(target.key);
                setResult(
                  'switchCommunity → "${target.label}" succeeded. Active key '
                  'now ${_redactKey(app.activeApiKey)}. isInitialised='
                  '${app.isInitialised}, connectionState='
                  '${_connectionLabel(app.connectionState)}. Reconnect the '
                  'user and rebuild any embedded view with a fresh key.',
                );
              } catch (e) {
                setResult('switchCommunity failed: $e', isError: true);
              }
            },
          ),
      ],
    );
  }
}
