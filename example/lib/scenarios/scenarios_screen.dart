import 'package:flutter/material.dart';

import '../app_state.dart';
import '../design.dart';
import '../feature_toggles.dart';
import '../widgets/scenario_scaffold.dart';
import 'bridge_to_client_object_scenario.dart';
import 'community_access_scenario.dart';
import 'community_data_scenario.dart';
import 'connection_scenario.dart';
import 'content_options_scenario.dart';
import 'create_post_scenario.dart';
import 'custom_events_scenario.dart';
import 'embedded_back_scenario.dart';
import 'events_scenario.dart';
import 'force_octopus_ab_tests_scenario.dart';
import 'fullscreen_scenario.dart';
import 'group_access_denied_scenario.dart';
import 'groups_scenario.dart';
import 'initial_screen_scenario.dart';
import 'locale_scenario.dart';
import 'modal_scenario.dart';
import 'not_seen_notifications_scenario.dart';
import 'profile_fields_lock_scenario.dart';
import 'push_notifications_scenario.dart';
import 'reactions_scenario.dart';
import 'refresh_entitlements_scenario.dart';
import 'sheet_scenario.dart';
import 'switch_community_scenario.dart';
import 'sync_follow_groups_scenario.dart';
import 'terms_acceptance_scenario.dart';
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

class _ScenarioSection {
  /// Section id — drives the header test_id `scenarios-section-<id>`.
  ///
  /// Divergence accepted against the Android reference, which derives its tag
  /// from the enum name (`theme`, `host`): these ids predate the port and are
  /// already wired into the QA scenarios, so `themeLanguage` and `hostCallbacks`
  /// stay. Titles and order are iso.
  final String id;
  final String title;

  /// The feature toggle this section owns, or `null` when nothing about it is
  /// switchable. Two sections carry one; Presentation modes deliberately does
  /// not — a presentation mode is something you do, not something you leave on.
  final FeatureToggle? featureToggle;

  final List<_ScenarioDescriptor> scenarios;

  const _ScenarioSection({
    required this.id,
    required this.title,
    required this.scenarios,
    this.featureToggle,
  });
}

// Top-level builders keep the descriptor lists `const`.
Widget _connection(BuildContext _) => const ConnectionScenario();
Widget _syncFollowGroups(BuildContext _) => const SyncFollowGroupsScenario();
Widget _groups(BuildContext _) => const GroupsScenario();
Widget _communityAccess(BuildContext _) => const CommunityAccessScenario();
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
Widget _profileFieldsLock(BuildContext _) => const ProfileFieldsLockScenario();
Widget _termsAcceptance(BuildContext _) => const TermsAcceptanceScenario();
Widget _contentOptions(BuildContext _) => const ContentOptionsScenario();

/// The catalog scenarios whose `platforms` include `flutter`, grouped the way
/// the shared sample design groups them — same six sections, same order, on
/// every platform.
const List<_ScenarioSection> _sections = [
  _ScenarioSection(
    id: 'sso',
    title: 'Sign-in & user',
    featureToggle: FeatureToggle.forceLogin,
    scenarios: [
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
      _ScenarioDescriptor(
        id: 'profileFieldsLock',
        title: 'Profile Field Lock',
        subtitle:
            'The locked fields turn read-only in the community\'s profile '
            'editor.',
        api: 'debugOverrideProfileFieldsLock',
        icon: Icons.lock_person,
        builder: _profileFieldsLock,
      ),
      _ScenarioDescriptor(
        id: 'termsAcceptance',
        title: 'Terms Acceptance (Consent)',
        subtitle:
            'The community asks for consent the way you picked, or stops '
            'asking altogether.',
        api: 'debugOverrideTermsAcceptanceMode',
        icon: Icons.gavel,
        builder: _termsAcceptance,
      ),
    ],
  ),
  // No feature toggle here on purpose: a presentation mode is a route to open,
  // not a state to leave on.
  _ScenarioSection(
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
  _ScenarioSection(
    id: 'community',
    title: 'Community & groups',
    scenarios: [
      _ScenarioDescriptor(
        id: 'groups',
        title: 'Browse Groups',
        subtitle:
            'Every group the community offers, with a follow toggle on each row',
        api: 'fetchGroups',
        icon: Icons.groups,
        builder: _groups,
      ),
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
        id: 'contentOptions',
        title: 'Content Options',
        subtitle:
            'The composer offers only the kinds of content the community '
            'allows.',
        api: 'debugOverrideContentOptions',
        icon: Icons.tune,
        builder: _contentOptions,
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
  _ScenarioSection(
    id: 'notifications',
    title: 'Notifications',
    featureToggle: FeatureToggle.pushRegistration,
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
  _ScenarioSection(
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
    scenarios: [
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
        id: 'communityAccess',
        title: 'Community Access',
        subtitle: 'Grant or deny access to the community, or just report it',
        api: 'overrideCommunityAccess',
        icon: Icons.lock_open,
        builder: _communityAccess,
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
///
/// Every section starts closed, iso the Android reference: the screen opens on
/// the six headers, which is the map of the sample, rather than on one section's
/// cards. The two feature toggles stay reachable regardless — they render
/// outside the collapse.
final Map<String, bool> _expanded = {
  for (final section in _sections) section.id: false,
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

  /// One key per section header, so a request to land on a section
  /// ([AppState.requestScenariosSection]) can scroll it into view.
  final Map<String, GlobalKey> _sectionKeys = {
    for (final section in _sections) section.id: GlobalKey(),
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Also subscribes this tab to AppScope, so a request made while the tab is
    // already mounted under a scenario route is seen here too. `take` clears
    // it: one request, one landing.
    final requested = AppScope.maybeOf(
      context,
    )?.takeRequestedScenariosSection();
    if (requested == null || !_sectionKeys.containsKey(requested)) return;
    if (_query.trim().isEmpty) _expanded[requested] = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _sectionKeys[requested]?.currentContext;
      // A search that filtered the section out leaves nothing to scroll to.
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

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

    return Semantics(
      identifier: 'scenarios-screen',
      container: true,
      child: Column(
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
                // Not a ListView.builder: a builder only builds what is near
                // the viewport, and a section asked for from a scenario
                // screen has to exist to be scrolled to. Six sections.
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (section, hits) in visible)
                          _Section(
                            key: _sectionKeys[section.id],
                            section: section,
                            scenarios: hits,
                            // A search unfolds whatever it matched; without one the
                            // remembered state decides.
                            expanded:
                                searching || (_expanded[section.id] ?? false),
                            onToggleExpanded: searching
                                ? null
                                : () => setState(() {
                                    _expanded[section.id] =
                                        !(_expanded[section.id] ?? false);
                                  }),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    super.key,
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
    final toggle = section.featureToggle;

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
              child: ConstrainedBox(
                // 48dp is the header's touch target, not its decoration: this
                // row is the only way to open a section.
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          section.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CountPill(count: scenarios.length),
                      const Spacer(),
                      Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Outside the collapse on purpose: a QA run resolves
          // `scenarios-toggle-*` from a cold start, where every section is
          // closed, and a toggle that first needs its section expanded is a
          // toggle that is not there.
          if (toggle != null) _FeatureToggleRow(toggle: toggle),
          if (expanded)
            for (final descriptor in scenarios)
              _ScenarioCard(section: section, descriptor: descriptor),
        ],
      ),
    );
  }
}

/// How many scenarios the section holds — the filtered count while a search is
/// running.
class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// The section header's feature toggle: the switch, and under it the one
/// sentence that says what changes on screen in this position.
///
/// The effect line is not decoration. "A switch flips and nothing on screen
/// says what changed" is the defect this row exists to close — with, on the
/// developer side, the Debug console entry [AppState.setFeatureToggle] writes.
class _FeatureToggleRow extends StatelessWidget {
  const _FeatureToggleRow({required this.toggle});

  final FeatureToggle toggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = AppScope.of(context);
    final enabled = app.featureToggles[toggle];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: sampleBorderFor(theme.brightness)),
        borderRadius: BorderRadius.circular(12),
        color: sampleTintFor(theme.brightness),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  toggle.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  toggle.effectLine(enabled),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            identifier: toggle.testId,
            child: Switch(
              value: enabled,
              onChanged: (on) => app.setFeatureToggle(toggle, on),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final _ScenarioSection section;
  final _ScenarioDescriptor descriptor;

  const _ScenarioCard({required this.section, required this.descriptor});

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
            // The scope tells the scenario screen which section it came from:
            // its read-only feature-state line and the way back to the switch.
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ScenarioSectionScope(
                  sectionId: section.id,
                  featureToggle: section.featureToggle,
                  child: descriptor.builder(context),
                ),
              ),
            ),
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
