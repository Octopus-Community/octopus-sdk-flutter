import 'package:flutter/material.dart';

import '../app_state.dart';
import '../design.dart';
import '../widgets/key_value_card.dart';
import '../widgets/scenario_scaffold.dart';

class UnifiedProfileScenario extends StatefulWidget {
  const UnifiedProfileScenario({super.key});

  @override
  State<UnifiedProfileScenario> createState() => _UnifiedProfileScenarioState();
}

class _UnifiedProfileScenarioState extends State<UnifiedProfileScenario> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).refreshCommunityConfig();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final active =
        app.unifiedProfileWired &&
        (app.exposeClientUserIdOverride.enabled ??
            app.communityConfig?.exposeClientUserId ??
            false);
    return ScenarioScaffold(
      title: 'Unified Profile',
      api: 'onNavigateToProfile',
      description: 'Open member profiles in the host app or in the community.',
      youWillSee:
          'with the switch on, a member with an app id opens Client '
          'profile and the home profile button opens Activity; with it off, '
          'both open native profiles.',
      resultTestId: 'unifiedProfile-result',
      presets: const [],
      hidesResult: true,
      verifyInCommunity: true,
      controls: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Unified Profile needs both the community flag and a host '
            'profile callback. Members without an app id keep the native '
            'Octopus profile flow.',
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Unified profile'),
            subtitle: Text(
              active
                  ? 'Profile taps open Client profile'
                  : app.unifiedProfileWired &&
                        app.exposeClientUserIdOverride.enabled == null &&
                        app.communityConfig == null
                  ? 'Community flag unavailable'
                  : 'Profile taps open native profiles',
            ),
            value: active,
            onChanged: (enabled) async {
              app.setUnifiedProfileWired(enabled);
              await app.setExposeClientUserIdOverride(
                enabled
                    ? ExposeClientUserIdOverride.forceOn
                    : ExposeClientUserIdOverride.backend,
              );
            },
          ),
          const Text(
            'The community view remounts with the new profile callback. '
            'No SDK restart is needed for this Flutter integration.',
          ),
          const SizedBox(height: SampleSpacing.space2),
          ExpansionTile(
            title: const Text('Backend flag override'),
            tilePadding: EdgeInsets.zero,
            children: [
              const Text(
                'Inspect either condition independently. Use the '
                'backend value, or force the community flag on. '
                'Turning Unified profile off restores the backend value '
                'and removes the host profile callback.',
              ),
              for (final choice in ExposeClientUserIdOverride.values)
                Semantics(
                  identifier: choice.testId,
                  selected: app.exposeClientUserIdOverride == choice,
                  child: OutlinedButton(
                    onPressed: () => app.setExposeClientUserIdOverride(choice),
                    child: Text(switch (choice) {
                      ExposeClientUserIdOverride.backend => 'Use backend value',
                      ExposeClientUserIdOverride.forceOn => 'Force flag on',
                    }),
                  ),
                ),
            ],
          ),
        ],
      ),
      liveState: KeyValueCard(
        title: 'Live state',
        rows: [
          ('Host profile callback', app.unifiedProfileWired ? 'on' : 'off'),
          ('Unified Profile', app.exposeClientUserIdSummary),
        ],
      ),
    );
  }
}
