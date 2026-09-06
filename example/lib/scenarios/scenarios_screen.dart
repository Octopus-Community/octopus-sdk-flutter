import 'package:flutter/material.dart';

import '../app_state.dart';
import '../design.dart';
import 'bridge_to_client_object_scenario.dart';
import 'community_data_scenario.dart';
import 'connection_scenario.dart';
import 'create_post_scenario.dart';
import 'custom_events_scenario.dart';
import 'embedded_back_scenario.dart';
import 'events_scenario.dart';
import 'force_octopus_ab_tests_scenario.dart';
import 'fullscreen_scenario.dart';
import 'group_access_denied_scenario.dart';
import 'initial_screen_scenario.dart';
import 'locale_scenario.dart';
import 'modal_scenario.dart';
import 'not_seen_notifications_scenario.dart';
import 'push_notifications_scenario.dart';
import 'reactions_scenario.dart';
import 'refresh_entitlements_scenario.dart';
import 'sheet_scenario.dart';
import 'switch_community_scenario.dart';
import 'sync_follow_groups_scenario.dart';
import 'theme_scenario.dart';
import 'track_ab_tests_scenario.dart';

/// One entry in the searchable scenario list.
class _ScenarioDescriptor {
  /// Catalog scenario id — drives the card test_id `scenarios-<id>-card`.
  final String id;
  final String title;
  final String subtitle;

  /// The SDK symbol this scenario exercises, shown as a monospace pill and
  /// searchable like the title. Never a made-up name: every one of these is
  /// called by the scenario it labels.
  final String api;
  final IconData icon;
  final WidgetBuilder builder;

  const _ScenarioDescriptor({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.api,
    required this.icon,
    required this.builder,
  });

  bool matches(String query) =>
      title.toLowerCase().contains(query) ||
      subtitle.toLowerCase().contains(query) ||
      api.toLowerCase().contains(query);
}

/// A quick toggle a section header can carry, for the sections whose group has
/// one dominant on/off state. Presentation modes deliberately has none — there
/// is nothing to switch, only routes to open.
class _SectionToggle {
  final String label;
  final bool Function(AppState) value;
  final Future<void> Function(AppState, bool) onChanged;

  const _SectionToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });
}

class _ScenarioSection {
  final String id;
  final String title;
  final _SectionToggle? toggle;
  final List<_ScenarioDescriptor> scenarios;

  const _ScenarioSection({
    required this.id,
    required this.title,
    required this.scenarios,
    this.toggle,
  });
}

// Top-level builders keep the descriptor lists `const`.
Widget _connection(BuildContext _) => const ConnectionScenario();
Widget _syncFollowGroups(BuildContext _) => const SyncFollowGroupsScenario();
Widget _customEvents(BuildContext _) => const CustomEventsScenario();
Widget _locale(BuildContext _) => const LocaleScenario();
Widget _theme(BuildContext _) => const ThemeScenario();
Widget _bridgeToClientObject(BuildContext _) =>
    const BridgeToClientObjectScenario();
Widget _initialScreen(BuildContext _) => const InitialScreenScenario();
Widget _switchCommunity(BuildContext _) => const SwitchCommunityScenario();
Widget _refreshEntitlements(BuildContext _) =>
    const RefreshEntitlementsScenario();
Widget _groupAccessDenied(BuildContext _) => const GroupAccessDeniedScenario();
Widget _reactions(BuildContext _) => const ReactionsScenario();
Widget _createPost(BuildContext _) => const CreatePostScenario();
Widget _modal(BuildContext _) => const ModalScenario();
Widget _embeddedBack(BuildContext _) => const EmbeddedBackScenario();
Widget _fullscreen(BuildContext _) => const FullscreenScenario();
Widget _sheet(BuildContext _) => const SheetScenario();
Widget _events(BuildContext _) => const EventsScenario();
Widget _notSeenNotifications(BuildContext _) =>
    const NotSeenNotificationsScenario();
Widget _pushNotifications(BuildContext _) => const PushNotificationsScenario();
Widget _trackABTests(BuildContext _) => const TrackABTestsScenario();
Widget _forceOctopusABTests(BuildContext _) =>
    const ForceOctopusABTestsScenario();
Widget _communityData(BuildContext _) => const CommunityDataScenario();

/// The catalog scenarios whose `platforms` include `flutter`, grouped the way
/// the shared sample design groups them — same six sections, same order, on
/// every platform.
final List<_ScenarioSection> _sections = [
  _ScenarioSection(
    id: 'sso',
    title: 'SSO & user',
    toggle: _SectionToggle(
      label: 'Connected',
      value: (app) => app.userConnected,
      onChanged: (app, on) async {
        if (on) {
          await app.connectDemoUser(entitlements: app.currentEntitlements);
        } else {
          await app.disconnectUser();
        }
      },
    ),
    scenarios: const [
      _ScenarioDescriptor(
        id: 'connection',
        title: 'Connection',
        subtitle: 'Connect and disconnect the SSO test user',
        api: 'connectUser / disconnectUser',
        icon: Icons.login,
        builder: _connection,
      ),
      _ScenarioDescriptor(
        id: 'refreshEntitlements',
        title: 'Refresh Entitlements',
        subtitle: 'Refresh the session entitlements without reconnecting',
        api: 'refreshEntitlements',
        icon: Icons.refresh,
        builder: _refreshEntitlements,
      ),
      _ScenarioDescriptor(
        id: 'communityData',
        title: 'Community Data (Unified Profile)',
        subtitle: 'Read the community profile behind a client user id',
        api: 'communityDataFlow',
        icon: Icons.badge,
        builder: _communityData,
      ),
    ],
  ),
  const _ScenarioSection(
    id: 'community',
    title: 'Community & groups',
    scenarios: [
      _ScenarioDescriptor(
        id: 'syncFollowGroups',
        title: 'Sync Followed Groups',
        subtitle: 'Batch follow / unfollow the groups of the community',
        api: 'syncFollowGroups',
        icon: Icons.group_work,
        builder: _syncFollowGroups,
      ),
      _ScenarioDescriptor(
        id: 'lifecycle',
        title: 'Switch Community',
        subtitle: 'Point the running SDK at another community',
        api: 'switchCommunity',
        icon: Icons.swap_horiz,
        builder: _switchCommunity,
      ),
      _ScenarioDescriptor(
        id: 'groupAccessDenied',
        title: 'Group Access Denied',
        subtitle: 'Handle a group the current user may not enter',
        api: 'setGroupAccessDeniedCallback',
        icon: Icons.block,
        builder: _groupAccessDenied,
      ),
      _ScenarioDescriptor(
        id: 'reactions',
        title: 'Reactions',
        subtitle: 'React, change reaction and unreact on a post',
        api: 'setReaction',
        icon: Icons.favorite,
        builder: _reactions,
      ),
      _ScenarioDescriptor(
        id: 'createPost',
        title: 'Create Post (Bridge Share)',
        subtitle: 'Open the post editor prefilled by the host',
        api: 'showOctopusCreatePostScreen',
        icon: Icons.post_add,
        builder: _createPost,
      ),
      _ScenarioDescriptor(
        id: 'bridge',
        title: 'Bridge → Client Object',
        subtitle: 'Attach a community post to an object the host owns',
        api: 'setNavigateToClientObjectCallback',
        icon: Icons.link,
        builder: _bridgeToClientObject,
      ),
      _ScenarioDescriptor(
        id: 'initialScreen',
        title: 'Initial Screen',
        subtitle: 'Open the community on a chosen entry screen',
        api: 'OctopusInitialScreen',
        icon: Icons.dashboard,
        builder: _initialScreen,
      ),
    ],
  ),
  const _ScenarioSection(
    id: 'notifications',
    title: 'Notifications',
    scenarios: [
      _ScenarioDescriptor(
        id: 'notSeenNotifications',
        title: 'Not-Seen Notifications',
        subtitle: 'Read and reset the unseen notification count',
        api: 'notSeenNotificationsCount',
        icon: Icons.mark_chat_unread,
        builder: _notSeenNotifications,
      ),
      _ScenarioDescriptor(
        id: 'pushNotifications',
        title: 'Push Notifications',
        subtitle: 'Recognise and open an Octopus push payload',
        api: 'isOctopusNotification / openNotification',
        icon: Icons.notifications_active,
        builder: _pushNotifications,
      ),
    ],
  ),
  // No quick toggle here on purpose: a presentation mode is a route to open,
  // not a state to switch on.
  const _ScenarioSection(
    id: 'presentation',
    title: 'Presentation modes',
    scenarios: [
      _ScenarioDescriptor(
        id: 'fullscreen',
        title: 'Fullscreen',
        subtitle: 'Push the community as a standard route',
        api: 'showOctopusHomeScreen',
        icon: Icons.fullscreen,
        builder: _fullscreen,
      ),
      _ScenarioDescriptor(
        id: 'sheet',
        title: 'Sheet',
        subtitle: 'Present the community in a 90% bottom sheet',
        api: 'showModalBottomSheet',
        icon: Icons.swipe_up,
        builder: _sheet,
      ),
      _ScenarioDescriptor(
        id: 'modal',
        title: 'Modal',
        subtitle: 'Present the community as a full-screen dialog',
        api: 'fullscreenDialog',
        icon: Icons.layers,
        builder: _modal,
      ),
      _ScenarioDescriptor(
        id: 'embeddedBack',
        title: 'Embedded Back Button',
        subtitle: "Pick the SDK's leading icon and watch onBack fire",
        api: 'navBarLeadingAction',
        icon: Icons.arrow_back,
        builder: _embeddedBack,
      ),
    ],
  ),
  const _ScenarioSection(
    id: 'themeLanguage',
    title: 'Theme & language',
    scenarios: [
      _ScenarioDescriptor(
        id: 'theme',
        title: 'Theme',
        subtitle: 'Apply a custom OctopusTheme to the SDK surface',
        api: 'OctopusTheme',
        icon: Icons.palette,
        builder: _theme,
      ),
      _ScenarioDescriptor(
        id: 'locale',
        title: 'Locale',
        subtitle: 'Override the locale the SDK UI renders in',
        api: 'overrideDefaultLocale',
        icon: Icons.language,
        builder: _locale,
      ),
    ],
  ),
  _ScenarioSection(
    id: 'hostCallbacks',
    title: 'Host callbacks & events',
    toggle: _SectionToggle(
      label: 'Host handles profile taps',
      value: (app) => app.unifiedProfileWired,
      onChanged: (app, on) async => app.setUnifiedProfileWired(on),
    ),
    scenarios: const [
      _ScenarioDescriptor(
        id: 'events',
        title: 'Events Log',
        subtitle: 'Observe every event the SDK emits',
        api: 'OctopusSDK.events',
        icon: Icons.list_alt,
        builder: _events,
      ),
      _ScenarioDescriptor(
        id: 'customEvents',
        title: 'Custom Events',
        subtitle: 'Send a host analytics event through the SDK',
        api: 'trackCustomEvent',
        icon: Icons.insights,
        builder: _customEvents,
      ),
      _ScenarioDescriptor(
        id: 'trackABTests',
        title: 'Track A/B Tests',
        subtitle: 'Report a host experiment alongside community access',
        api: 'trackCommunityAccess',
        icon: Icons.science,
        builder: _trackABTests,
      ),
      _ScenarioDescriptor(
        id: 'forceOctopusABTests',
        title: 'Force Octopus A/B Tests',
        subtitle: 'Force a community-access variant for QA',
        api: 'overrideCommunityAccess',
        icon: Icons.flag,
        builder: _forceOctopusABTests,
      ),
    ],
  ),
];

/// Which sections are open. Kept outside the State so the choice survives a tab
/// switch — a tester who opened Notifications finds it open on the way back.
final Map<String, bool> _expanded = {
  for (final section in _sections) section.id: section.id == 'sso',
};

/// Scenarios tab — six collapsible sections of scenario cards, over one search
/// field that spans titles, descriptions and API names.
class ScenariosTab extends StatefulWidget {
  const ScenariosTab({super.key});

  @override
  State<ScenariosTab> createState() => _ScenariosTabState();
}

class _ScenariosTabState extends State<ScenariosTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final searching = query.isNotEmpty;

    final visible = <(_ScenarioSection, List<_ScenarioDescriptor>)>[];
    for (final section in _sections) {
      final hits = searching
          ? section.scenarios.where((s) => s.matches(query)).toList()
          : section.scenarios;
      if (hits.isNotEmpty) visible.add((section, hits));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Semantics(
            identifier: 'scenarios-search-input',
            textField: true,
            container: true,
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search scenarios',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const Center(child: Text('No scenario matches your search.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final (section, hits) = visible[index];
                    return _Section(
                      section: section,
                      scenarios: hits,
                      // A search unfolds whatever it matched; without one the
                      // remembered state decides.
                      expanded: searching || (_expanded[section.id] ?? false),
                      onToggleExpanded: searching
                          ? null
                          : () => setState(() {
                              _expanded[section.id] =
                                  !(_expanded[section.id] ?? false);
                            }),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.section,
    required this.scenarios,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final _ScenarioSection section;
  final List<_ScenarioDescriptor> scenarios;
  final bool expanded;
  final VoidCallback? onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = AppScope.of(context);
    final toggle = section.toggle;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            identifier: 'scenarios-section-${section.id}',
            container: true,
            child: InkWell(
              onTap: onToggleExpanded,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        section.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (toggle != null)
                      Semantics(
                        identifier: 'scenarios-section-${section.id}-toggle',
                        container: true,
                        child: Row(
                          children: [
                            Text(
                              toggle.label,
                              style: theme.textTheme.bodySmall,
                            ),
                            Switch(
                              value: toggle.value(app),
                              onChanged: (on) => toggle.onChanged(app, on),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            for (final descriptor in scenarios)
              _ScenarioCard(descriptor: descriptor),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final _ScenarioDescriptor descriptor;

  const _ScenarioCard({required this.descriptor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return MergeSemantics(
      child: Semantics(
        identifier: 'scenarios-${descriptor.id}-card',
        button: true,
        child: Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: sampleBorderFor(brightness)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: descriptor.builder)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    descriptor.icon,
                    size: 22,
                    color: sampleAccent(brightness),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          descriptor.title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          descriptor.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ApiPill(descriptor.api),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
