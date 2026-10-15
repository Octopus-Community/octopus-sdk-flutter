import 'package:flutter/material.dart';

import '../app_state.dart';
import '../community/community_navigation.dart';
import '../config/host_integration.dart';
import '../design.dart';
import 'settings_choices.dart';

class HostIntegrationScreen extends StatelessWidget {
  const HostIntegrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return SampleScaffold(
      appBar: SampleTopAppBar(title: 'Host app integration'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SampleSpacing.space4),
          children: [
            Text('What the sample app handles itself when the community asks.'),
            const SizedBox(height: SampleSpacing.space4),
            SampleSection(
              title: 'Community navigation',
              child: SettingsChoices<CommunityNavigation>(
                segmented: true,
                identifier: 'community-navigation-select',
                selected: app.communityNavigation,
                options: [
                  for (final mode in CommunityNavigation.values)
                    (mode, mode.label),
                ],
                onChanged: app.setCommunityNavigation,
              ),
            ),
            const SizedBox(height: SampleSpacing.space4),
            SampleGroupHeader(
              'Callbacks',
              count: '${app.wiredHostCallbackCount}/5',
              identifier: 'host-integration-callbacks-count',
            ),
            SampleListGroup(
              children: [
                SampleSwitchRow(
                  title: 'Route profile taps to your own profile screen',
                  subtitle:
                      'onNavigateToProfile\nAlso needs Unified Profile enabled for the community.',
                  value: app.unifiedProfileWired,
                  onChanged: app.setUnifiedProfileWired,
                ),
                SampleSwitchRow(
                  title: 'App profile editor',
                  subtitle: 'onNavigateToProfileEdit (Flutter: onModifyUser)',
                  value: app.hostProfileEditWired,
                  onChanged: app.setHostProfileEditWired,
                ),
                SampleSwitchRow(
                  title: 'Open your sign-in screen',
                  subtitle: 'onNavigateToLogin',
                  value: app.onAuthenticationRequiredWired,
                  onChanged: app.setOnAuthenticationRequiredWired,
                ),
                SampleSwitchRow(
                  title: 'Handle taps on the content button',
                  subtitle: 'onNavigateToClientObject',
                  value: app.onNavigateToContentWired,
                  onChanged: app.setOnNavigateToContentWired,
                ),
                SampleSwitchRow(
                  title: 'Gate access to locked groups',
                  subtitle:
                      'onGroupAccessDenied\nOpening a locked group lets the app answer with its own dialog.',
                  value: app.hostGroupAccessWired,
                  onChanged: app.setHostGroupAccessWired,
                ),
              ],
            ),
            const SizedBox(height: SampleSpacing.space4),
            SampleSection(
              title: 'Handle link taps',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('onNavigateToUrl'),
                  SettingsChoices<HostUrlHandling>(
                    identifier: 'host-integration-url-select',
                    selected: app.hostUrlHandling,
                    disabledOptions: const {HostUrlHandling.sampleRule},
                    options: [
                      for (final option in HostUrlHandling.values)
                        (option, option.label),
                    ],
                    onChanged: app.setHostUrlHandling,
                  ),
                  const Text(
                    'The selective sample rule is unavailable. Choose who opens all links.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: SampleSpacing.space4),
            const Text(
              'Changes are saved and apply immediately. Mount-time changes reopen the community view.',
            ),
          ],
        ),
      ),
    );
  }
}
