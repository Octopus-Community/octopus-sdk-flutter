import 'package:flutter/material.dart';

import 'scenario_copy.dart';
import 'unified_profile_scenario.dart';
import 'live_community_config_card.dart';

import '../app_state.dart';
import '../community/present_community.dart';
import '../design.dart';
import '../feature_toggles.dart';
import '../sample_tab.dart';
import '../widgets/scenario_scaffold.dart';
import 'bridge_to_client_object_scenario.dart';
import 'community_access_scenario.dart';
import 'community_data_scenario.dart';
import 'connection_scenario.dart';
import 'content_options_scenario.dart';
import 'consent_texts_scenario.dart';
import 'force_nickname_choice_scenario.dart';
import 'create_post_scenario.dart';
import 'custom_events_scenario.dart';
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
  final WidgetBuilder builder;

  const _ScenarioDescriptor({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.api,
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
Widget _unifiedProfile(BuildContext _) => const UnifiedProfileScenario();
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
Widget _forceNicknameChoice(BuildContext _) =>
    const ForceNicknameChoiceScenario();
Widget _consentTexts(BuildContext _) => const ConsentTextsScenario();
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
        id: 'unifiedProfile',
        title: "Unified Profile",
        subtitle: "Open member profiles in the host app or in the community.",
        api: 'onNavigateToProfile',
        builder: _unifiedProfile,
      ),
      _ScenarioDescriptor(
        id: 'connection',
        title: "Sign in and out as the demo user",
        subtitle:
            "The community shows the demo user as signed in: they can post, react and be notified.",
        api: 'connectUser / disconnectUser',
        builder: _connection,
      ),
      _ScenarioDescriptor(
        id: 'communityData',
        title: "Read a member's community profile",
        subtitle:
            "The member's community profile comes back, and keeps updating while you watch it.",
        api: "fetchCommunityData / communityDataFlow",
        builder: _communityData,
      ),
      _ScenarioDescriptor(
        id: 'profileFieldsLock',
        title: "Lock the profile fields the host owns",
        subtitle:
            "The locked fields turn read-only in the community's profile editor.",
        api: 'debugOverrideProfileFieldsLock',
        builder: _profileFieldsLock,
      ),
      _ScenarioDescriptor(
        id: 'forceNicknameChoice',
        title: 'Force Nickname Choice',
        subtitle: 'Choose the initial nickname before a first contribution.',
        api: 'debugOverrideForceNicknameChoice',
        builder: _forceNicknameChoice,
      ),
      _ScenarioDescriptor(
        id: 'termsAcceptance',
        title: "Change how members accept the terms",
        subtitle:
            "The community asks for consent the way you picked, or stops asking altogether.",
        api: 'debugOverrideTermsAcceptanceMode',
        builder: _termsAcceptance,
      ),
      _ScenarioDescriptor(
        id: 'consentTexts',
        title: 'Consent Texts (community wording)',
        subtitle: 'Show community consent wordings and native fallback.',
        api: 'debugOverrideConsentTexts',
        builder: _consentTexts,
      ),
      _ScenarioDescriptor(
        id: 'refreshEntitlements',
        title: "Re-issue the demo user's entitlements",
        subtitle:
            "The community picks up the entitlements you edited, without signing out.",
        api: 'refreshEntitlements',
        builder: _refreshEntitlements,
      ),
    ],
  ),
  _ScenarioSection(
    id: 'presentation',
    title: 'Presentation modes',
    scenarios: [
      _ScenarioDescriptor(
        id: 'initialScreen',
        title: "Open the community on a chosen screen",
        subtitle:
            "The community opens directly on the member, profile or feed you picked.",
        api: 'OctopusInitialScreen',
        builder: _initialScreen,
      ),
      _ScenarioDescriptor(
        id: 'fullscreen',
        title: "Open the community full screen",
        subtitle: "The community takes the whole screen, outside the tab bar.",
        api: "host: MaterialPageRoute",
        builder: _fullscreen,
      ),
      _ScenarioDescriptor(
        id: 'modal',
        title: "Open the community as a modal",
        subtitle:
            "The community covers the screen in a host-owned modal that you close yourself.",
        api: "host: fullscreenDialog",
        builder: _modal,
      ),
      _ScenarioDescriptor(
        id: 'sheet',
        title: "Open the community as a bottom sheet",
        subtitle:
            "The community slides over this screen; swipe down to come back.",
        api: "host: showModalBottomSheet",
        builder: _sheet,
      ),
    ],
  ),
  _ScenarioSection(
    id: 'community',
    title: 'Community & groups',
    scenarios: [
      _ScenarioDescriptor(
        id: 'groups',
        title: "Browse the community's groups",
        subtitle:
            "Every group the community offers, with whether the demo user follows it.",
        api: 'fetchGroups',
        builder: _groups,
      ),
      _ScenarioDescriptor(
        id: 'syncFollowGroups',
        title: "Follow or unfollow every group at once",
        subtitle:
            "The follow state of every group flips in one call, and the community reflects it.",
        api: 'syncFollowGroups',
        builder: _syncFollowGroups,
      ),
      _ScenarioDescriptor(
        id: 'communityAccess',
        title: "Grant or deny access to the community",
        subtitle:
            "The community either opens normally, or shows its no-access state.",
        api: 'overrideCommunityAccess',
        builder: _communityAccess,
      ),
      _ScenarioDescriptor(
        id: 'bridge',
        title: "Open the post attached to a product",
        subtitle:
            "A post tied to a host object opens — created on the spot the first time you ask for it.",
        api: 'setNavigateToClientObjectCallback',
        builder: _bridgeToClientObject,
      ),
      _ScenarioDescriptor(
        id: 'createPost',
        title: "Start a post from the host app",
        subtitle:
            "The composer opens pre-filled with the text, image or link the host handed over.",
        api: 'showOctopusCreatePostScreen',
        builder: _createPost,
      ),
      _ScenarioDescriptor(
        id: 'reactions',
        title: "React to a post from the host app",
        subtitle:
            "The reaction you picked shows on that post in the community.",
        api: 'setReaction',
        builder: _reactions,
      ),
      _ScenarioDescriptor(
        id: 'contentOptions',
        title: "Change what members are allowed to post",
        subtitle:
            "The composer offers only the kinds of content the community allows.",
        api: 'debugOverrideContentOptions',
        builder: _contentOptions,
      ),
      _ScenarioDescriptor(
        id: 'groupAccessDenied',
        title: "Handle a member reaching a closed group",
        subtitle:
            "The host is told a group was refused, instead of the community handling it alone.",
        api: 'setGroupAccessDeniedCallback',
        builder: _groupAccessDenied,
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
        title: "Set the unread notification count",
        subtitle:
            "The notification badge in the community carries the number you set.",
        api: 'notSeenNotificationsCount',
        builder: _notSeenNotifications,
      ),
      _ScenarioDescriptor(
        id: 'pushNotifications',
        title: "Open a post from a push notification",
        subtitle:
            "A simulated push is recognised as an Octopus one and opens the post it points at.",
        api: 'isOctopusNotification / openNotification',
        builder: _pushNotifications,
      ),
    ],
  ),
  _ScenarioSection(
    id: 'themeLanguage',
    title: 'Theme & language',
    scenarios: [
      _ScenarioDescriptor(
        id: 'locale',
        title: "Switch the community's language",
        subtitle:
            "The community's own labels switch to the language you picked.",
        api: 'overrideDefaultLocale',
        builder: _locale,
      ),
      _ScenarioDescriptor(
        id: 'theme',
        title: "Apply the host's brand to the community",
        subtitle:
            "The community adopts the host's colours, fonts and logo — or drops back to the SDK's own look.",
        api: 'OctopusTheme',
        builder: _theme,
      ),
    ],
  ),
  _ScenarioSection(
    id: 'hostCallbacks',
    title: 'Host callbacks & events',
    scenarios: [
      _ScenarioDescriptor(
        id: 'customEvents',
        title: "Send a custom analytics event",
        subtitle:
            "The event shows up in the Events log, with the properties you attached.",
        api: 'trackCustomEvent',
        builder: _customEvents,
      ),
      _ScenarioDescriptor(
        id: 'lifecycle',
        title: "Restart or stop the SDK",
        subtitle:
            "The session ends and the community goes back to its not-connected state.",
        api: "reset / stop / switchCommunity",
        builder: _switchCommunity,
      ),
      _ScenarioDescriptor(
        id: 'events',
        title: "Watch what the SDK reports",
        subtitle: "Every event the SDK emits, live, as the community is used.",
        api: 'OctopusSDK.events',
        builder: _events,
      ),
      _ScenarioDescriptor(
        id: 'trackABTests',
        title: "Report which cohort the member is in",
        subtitle:
            "The community opens for the cohort you granted, and refuses the other one.",
        api: 'trackCommunityAccess',
        builder: _trackABTests,
      ),
      _ScenarioDescriptor(
        id: 'forceOctopusABTests',
        title: "Force Octopus's own A/B decision",
        subtitle:
            "The community's own access rule is overridden — granted or denied — until you clear it.",
        api: 'overrideCommunityAccess',
        builder: _forceOctopusABTests,
      ),
    ],
  ),
];

/// Scenarios tab — six collapsible sections of scenario cards, over one search
/// field that spans titles, descriptions and API names.
class ScenariosTab extends StatefulWidget {
  const ScenariosTab({super.key, this.active = true, this.onScrolled});

  final bool active;
  final ValueChanged<bool>? onScrolled;

  @override
  State<ScenariosTab> createState() => _ScenariosTabState();
}

class _ScenariosTabState extends State<ScenariosTab> {
  String _query = '';
  bool _scrolled = false;
  final Map<String, bool> _expanded = {};

  @override
  void didUpdateWidget(ScenariosTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) _expanded.clear();
  }

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
            padding: const EdgeInsets.fromLTRB(
              SampleSpacing.space4,
              SampleSpacing.space4,
              SampleSpacing.space4,
              SampleSpacing.space4,
            ),
            child: Semantics(
              identifier: 'scenarios-search-input',
              textField: true,
              container: true,
              child: SampleSearchField(
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
          ),
          Expanded(
            child: // Not a ListView.builder: a builder only builds what is near
                // the viewport, and a section asked for from a scenario
                // screen has to exist to be scrolled to. Six sections.
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.depth != 0) return false;
                    final scrolled = notification.metrics.pixels > 4;
                    if (_scrolled != scrolled) {
                      _scrolled = scrolled;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) widget.onScrolled?.call(scrolled);
                      });
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    primary: false,
                    padding: const EdgeInsets.fromLTRB(
                      SampleSpacing.space4,
                      0,
                      SampleSpacing.space4,
                      SampleSpacing.space6,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!searching) ...[
                          _CommunityShortcuts(),
                          const SizedBox(height: SampleSpacing.space3),
                          LiveCommunityConfigCard(active: widget.active),
                          const SizedBox(height: SampleSpacing.space3),
                        ],
                        if (visible.isEmpty)
                          Text('No scenario matches "${_query.trim()}".'),
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
          ),
        ],
      ),
    );
  }
}

/// Community containers, hidden while searching for a scenario.
class _CommunityShortcuts extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SampleScenarioBlock(
    title: 'Open the community',
    icon: Icons.forum_outlined,
    identifier: 'scenarios-open-community-card',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('The same community, in the container your app gives it.'),
        const SizedBox(height: SampleSpacing.space3),
        for (final row in [
          [('Tab', 'tab'), ('Modal', 'modal')],
          [('Sheet', 'sheet'), ('Full screen', 'fullscreen')],
        ]) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (index, entry) in row.indexed) ...[
                if (index != 0) const SizedBox(width: SampleSpacing.space2),
                Expanded(
                  child: Semantics(
                    identifier: 'open-community-${entry.$2}-button',
                    button: true,
                    child: entry.$2 == 'tab'
                        ? FilledButton(
                            onPressed: () => AppScope.of(
                              context,
                            ).requestTab(SampleTab.community.index),
                            child: Text(entry.$1),
                          )
                        : OutlinedButton(
                            onPressed: () => switch (entry.$2) {
                              'modal' => openCommunityModal(context),
                              'sheet' => openCommunitySheet(context),
                              _ => openCommunityFullScreen(context),
                            },
                            child: Text(entry.$1, textAlign: TextAlign.center),
                          ),
                  ),
                ),
              ],
            ],
          ),
          if (row.first.$2 == 'tab')
            const SizedBox(height: SampleSpacing.space2),
        ],
      ],
    ),
  );
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
    final app = AppScope.of(context);
    final enabled = toggle == null ? false : app.featureToggles[toggle];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            identifier: 'scenarios-section-${section.id}',
            container: true,
            explicitChildNodes: true,
            child: Material(
              color: sampleSurface3For(theme.brightness).withValues(alpha: .4),
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onToggleExpanded,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                section.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (toggle != null)
                                Text(
                                  app.config == null
                                      ? app.restoringConfig
                                            ? 'Configuration is loading. Try again in a moment.'
                                            : 'Configure the SDK in Settings to enable this switch.'
                                      : '${toggle.label}: ${toggle.effectLine(enabled)}',
                                  style: theme.textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${scenarios.length}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        if (toggle != null)
                          Semantics(
                            identifier: toggle.testId,
                            child: Switch(
                              value: enabled,
                              onChanged: app.config == null
                                  ? null
                                  : (on) => app.setFeatureToggle(toggle, on),
                            ),
                          ),
                        const SizedBox(width: 8),
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
          ),
          if (expanded) ...[
            const SizedBox(height: 8),
            for (final (i, descriptor) in scenarios.indexed) ...[
              if (i > 0) const SizedBox(height: 8),
              _ScenarioCard(section: section, descriptor: descriptor),
            ],
          ],
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
          margin: EdgeInsets.zero,
          color: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: sampleBorderFor(brightness)),
            borderRadius: BorderRadius.circular(SampleRadius.lg),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(SampleRadius.lg),
            // The scope tells the scenario screen which section it came from:
            // its read-only feature-state line and the way back to the switch.
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ScenarioSectionScope(
                  copy: scenarioCopy[descriptor.id],
                  api: descriptor.api,
                  sectionId: section.id,
                  featureToggle: section.featureToggle,
                  child: descriptor.builder(context),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(descriptor.title, style: SampleTypography.scenarioTitle),
                  const SizedBox(height: 4),
                  Text(
                    descriptor.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  ApiPill(descriptor.api),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
