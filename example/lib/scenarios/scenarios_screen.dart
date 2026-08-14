import 'package:flutter/material.dart';

import 'bridge_to_client_object_scenario.dart';
import 'community_data_scenario.dart';
import 'connection_scenario.dart';
import 'custom_events_scenario.dart';
import 'events_scenario.dart';
import 'force_octopus_ab_tests_scenario.dart';
import 'fullscreen_scenario.dart';
import 'group_access_denied_scenario.dart';
import 'initial_screen_scenario.dart';
import 'locale_scenario.dart';
import 'modal_scenario.dart';
import 'not_seen_notifications_scenario.dart';
import 'push_notifications_scenario.dart';
import 'refresh_entitlements_scenario.dart';
import 'set_reaction_scenario.dart';
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
  final IconData icon;
  final WidgetBuilder builder;

  const _ScenarioDescriptor({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });
}

/// The catalog scenarios whose `platforms` include `flutter`.
const List<_ScenarioDescriptor> _scenarios = [
  _ScenarioDescriptor(
    id: 'connection',
    title: 'Connection',
    subtitle: 'connectUser / disconnectUser',
    icon: Icons.login,
    builder: _connection,
  ),
  _ScenarioDescriptor(
    id: 'syncFollowGroups',
    title: 'Sync Followed Groups',
    subtitle: 'Batch follow / unfollow',
    icon: Icons.group_work,
    builder: _syncFollowGroups,
  ),
  _ScenarioDescriptor(
    id: 'customEvents',
    title: 'Custom Events',
    subtitle: 'Track analytics events',
    icon: Icons.insights,
    builder: _customEvents,
  ),
  _ScenarioDescriptor(
    id: 'locale',
    title: 'Locale',
    subtitle: 'Override default locale',
    icon: Icons.language,
    builder: _locale,
  ),
  _ScenarioDescriptor(
    id: 'theme',
    title: 'Theme',
    subtitle: 'Custom OctopusTheme',
    icon: Icons.palette,
    builder: _theme,
  ),
  _ScenarioDescriptor(
    id: 'bridgeToClientObject',
    title: 'Bridge → Client Object',
    subtitle: 'fetchOrCreateClientObjectRelatedPost + setReaction',
    icon: Icons.link,
    builder: _bridgeToClientObject,
  ),
  _ScenarioDescriptor(
    id: 'initialScreen',
    title: 'Initial Screen',
    subtitle: 'OctopusInitialScreen variants + details widgets',
    icon: Icons.dashboard,
    builder: _initialScreen,
  ),
  _ScenarioDescriptor(
    id: 'switchCommunity',
    title: 'Switch Community',
    subtitle: 'Runtime community switch',
    icon: Icons.swap_horiz,
    builder: _switchCommunity,
  ),
  _ScenarioDescriptor(
    id: 'refreshEntitlements',
    title: 'Refresh Entitlements',
    subtitle: 'refreshEntitlements() + profile stream',
    icon: Icons.refresh,
    builder: _refreshEntitlements,
  ),
  _ScenarioDescriptor(
    id: 'groupAccessDenied',
    title: 'Group Access Denied',
    subtitle: 'setGroupAccessDeniedCallback',
    icon: Icons.block,
    builder: _groupAccessDenied,
  ),
  _ScenarioDescriptor(
    id: 'setReaction',
    title: 'Set Reaction',
    subtitle: 'OctopusReactionKind cycle on a fake post',
    icon: Icons.favorite,
    builder: _setReaction,
  ),
  _ScenarioDescriptor(
    id: 'modal',
    title: 'Modal',
    subtitle: 'Full-screen modal route (fullscreenDialog)',
    icon: Icons.layers,
    builder: _modal,
  ),
  _ScenarioDescriptor(
    id: 'fullscreen',
    title: 'Fullscreen',
    subtitle: 'Standard route push hosting OctopusHomeScreen',
    icon: Icons.fullscreen,
    builder: _fullscreen,
  ),
  _ScenarioDescriptor(
    id: 'sheet',
    title: 'Sheet',
    subtitle: 'showModalBottomSheet at 90% height',
    icon: Icons.swipe_up,
    builder: _sheet,
  ),
  _ScenarioDescriptor(
    id: 'events',
    title: 'Events Log',
    subtitle: 'OctopusSDK.events stream',
    icon: Icons.list_alt,
    builder: _events,
  ),
  _ScenarioDescriptor(
    id: 'notSeenNotifications',
    title: 'Not-Seen Notifications',
    subtitle:
        'notSeenNotificationsCount stream + updateNotSeenNotificationsCount',
    icon: Icons.mark_chat_unread,
    builder: _notSeenNotifications,
  ),
  _ScenarioDescriptor(
    id: 'pushNotifications',
    title: 'Push Notifications',
    subtitle:
        'isOctopusNotification / getOctopusNotification / openNotification',
    icon: Icons.notifications_active,
    builder: _pushNotifications,
  ),
  _ScenarioDescriptor(
    id: 'trackABTests',
    title: 'Track A/B Tests',
    subtitle: 'trackABTest API + custom-event analytics',
    icon: Icons.science,
    builder: _trackABTests,
  ),
  _ScenarioDescriptor(
    id: 'forceOctopusABTests',
    title: 'Force Octopus A/B Tests',
    subtitle: 'forceOctopusABTest override for QA',
    icon: Icons.flag,
    builder: _forceOctopusABTests,
  ),
  _ScenarioDescriptor(
    id: 'communityData',
    title: 'Community Data (Unified Profile)',
    subtitle: 'fetchCommunityData / communityDataFlow + clientUserId',
    icon: Icons.badge,
    builder: _communityData,
  ),
];

// Top-level builders keep the descriptor list `const`.
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
Widget _setReaction(BuildContext _) => const SetReactionScenario();
Widget _modal(BuildContext _) => const ModalScenario();
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

/// Scenarios tab — a searchable list of scenario cards.
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
    final filtered = query.isEmpty
        ? _scenarios
        : _scenarios
              .where(
                (s) =>
                    s.title.toLowerCase().contains(query) ||
                    s.subtitle.toLowerCase().contains(query),
              )
              .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Semantics(
            identifier: 'scenarios-search-input',
            textField: true,
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
          child: filtered.isEmpty
              ? const Center(child: Text('No scenario matches your search.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _ScenarioCard(descriptor: filtered[index]),
                ),
        ),
      ],
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final _ScenarioDescriptor descriptor;

  const _ScenarioCard({required this.descriptor});

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        identifier: 'scenarios-${descriptor.id}-card',
        button: true,
        child: Card(
          child: ListTile(
            leading: Icon(descriptor.icon),
            title: Text(descriptor.title),
            subtitle: Text(descriptor.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: descriptor.builder)),
          ),
        ),
      ),
    );
  }
}
