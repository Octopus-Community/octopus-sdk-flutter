import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:octopus_sdk_flutter/octopus_sdk_flutter.dart';

import '../app_log.dart';
import '../app_state.dart';
import '../auth/bridge_token_signer.dart';
import '../auth/login_page.dart';
import '../auth/profile_edit_page.dart';
import '../octopus_demo_config.dart';
import '../widgets/scenario_scaffold.dart';

/// Initial-screen scenario — `OctopusInitialScreen` variants
/// (`mainFeed` / `post` / `group` / `activity` / `profile` / `createPost`) plus
/// the standalone `OctopusPostDetailsScreen` / `OctopusProfileScreen`
/// shorthands.
///
/// The scenario now ships a host-driven **input form** above the presets so
/// QA can plug a *real* post id / group id / prefill text / CTA — instead of
/// the previous hardcoded fake ids that only surfaced empty / not-found
/// states. Mirrors the iOS `InitialScreenView` + `PrefilledPostForm` shape:
///
/// - Preset 2 (post) reads the post id text field.
/// - Preset 3 (group) reads the group id selected from the live `app.groups`
///   dropdown (populated by the SDK `groups` stream — same source as the iOS
///   sample's `groupsCancellable`).
/// - Preset 4 (createPost) reads the prefill text + optional topic / CTA
///   label / CTA URL fields, then calls the `OctopusPrefilledPost` validating
///   factory inside a `try/catch` so QA can observe each
///   [OctopusPrefilledPostValidationError] subtype as the result panel text.
/// - Preset 5 (standalone post details) reuses the same post id field.
/// - Preset 6 opens the standalone native editor via
///   [OctopusSDK.showOctopusCreatePostScreen] with a prefilled image share and
///   a `bridgeShareTokenProvider` (signs the share in a pictures-off community;
///   wired on both platforms). Mirrors the native sample bridge-share section.
/// - Preset 7 opens the community via the top-level
///   [OctopusSDK.showOctopusHomeScreen] helper with no `bottomSafeAreaInset`
///   (auto inset) — the only preset exercising the client-facing helper whose
///   default auto-reserves the Android nav-bar inset (unlike presets 1-5,
///   which mount the widget directly and forward the inset themselves).
/// - Presets 8 & 9 open one member's posts
///   ([OctopusInitialScreen.activity]) by the two id kinds the wire
///   discriminates — the host app's own `clientUserId` and the member's Octopus
///   `profileId`. Preset 9 resolves a `profileId` with `fetchCommunityData`
///   when the field is empty, so it runs in one tap.
/// - Presets 10 & 11 open the standalone [OctopusProfileScreen] with and
///   without an id: another member's read-only profile, and the connected
///   user's own editable one. The Community tab reaches the same pair from the
///   place a Unified Profile host actually needs them — the host profile page
///   pushed by `onNavigateToProfile`.
///
/// Each preset pushes a new [MaterialPageRoute] hosting the requested
/// embedded view directly — without an outer host [AppBar] (only a top
/// [SafeArea]) — because the SDK already renders its own native top bar
/// (Android M3 `OctopusTopAppBar`, iOS `UINavigationBar`) with a back arrow on
/// every screen. Wrapping a host [AppBar] around it would stack two headers.
/// The top [SafeArea] (added in [_openRoute]) is still required: the Android
/// PlatformView consumes the system-bar insets, so without it the SDK top bar
/// would render under the status bar. The device bottom gesture-area inset is
/// forwarded to the SDK via `bottomSafeAreaInset` (not a host bottom [SafeArea])
/// so the embedded feed stays edge-to-edge while the SDK floats its
/// bottom-pinned content above the gesture area — the same idiom as the
/// Fullscreen / Modal / Sheet scenarios. The SDK's back arrow fires `onBack`,
/// which pops the host route.
///
/// **Preset 4 auto-pops on `PostCreated`.** The native embedded shell does
/// not yet expose a `createPostScreenDismissed` callback (tracked
/// internally), so
/// after a successful publish the native side keeps navigating internally
/// (typically to post-detail / feed) — leaving the host route mounted. The
/// Preset 4 `onRun` listens to the global [OctopusSDK.events] stream and
/// removes its own [MaterialPageRoute] on the first [PostCreatedEvent], so
/// QA gets the "publish → back to scenario" UX the standalone
/// [OctopusSDK.showOctopusCreatePostScreen] already provides. Remove this
/// host-side workaround once the native callback ships.
class InitialScreenScenario extends StatefulWidget {
  const InitialScreenScenario({super.key});

  @override
  State<InitialScreenScenario> createState() => _InitialScreenScenarioState();
}

class _InitialScreenScenarioState extends State<InitialScreenScenario> {
  // Default prefill text — long enough to clear the SDK's minimum-length
  // check (10 chars) so QA gets a valid payload on first tap and can shorten
  // it in the field to surface the typed `TextTooShort` validation error.
  static const String _defaultPrefillText =
      'A long enough prefill text from the host app demonstration scenario.';

  /// Display name of the group the dropdown defaults to when QA has not picked
  /// one yet — the stable open read+write group every demo community ships
  /// (per the demo backend fixtures). Falls back to the
  /// first available group when no group with this name is loaded.
  static const String _defaultGroupName = 'General';

  late final TextEditingController _postIdCtrl;
  late final TextEditingController _prefillTextCtrl;
  late final TextEditingController _ctaLabelCtrl;
  late final TextEditingController _ctaUrlCtrl;
  late final TextEditingController _memberClientUserIdCtrl;
  late final TextEditingController _memberProfileIdCtrl;

  /// Group id explicitly selected from the live `app.groups` dropdown (preset 3
  /// + the optional createPost `topicId` field). `null` means "none selected".
  String? _selectedGroupId;

  /// Whether QA has touched the group dropdown. While `false` the presets use a
  /// sensible default seeded from the live groups stream (see
  /// [_effectiveGroupId]); once `true` the explicit [_selectedGroupId] wins
  /// (including an explicit "— (none)" pick).
  bool _groupSelectionTouched = false;

  @override
  void initState() {
    super.initState();
    // Prefill the post-id field with the injected demo post id so presets 2 & 5
    // open live content out of the box. `--dart-define` injects a stable demo
    // post (OCTOPUS_DEMO_POST_ID) by default; a keyless / public build leaves
    // it empty and the presets fall back to manual entry. See
    // octopus_demo_config.dart.
    _postIdCtrl = TextEditingController(text: octopusDemoPostId);
    _prefillTextCtrl = TextEditingController(text: _defaultPrefillText);
    _ctaLabelCtrl = TextEditingController();
    _ctaUrlCtrl = TextEditingController();
    // Left empty on purpose: the member presets fall back to the connected
    // user's own ids (see [_effectiveMemberClientUserId]), which are not known
    // yet at initState time and change on every login / community switch.
    _memberClientUserIdCtrl = TextEditingController();
    _memberProfileIdCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _postIdCtrl.dispose();
    _prefillTextCtrl.dispose();
    _ctaLabelCtrl.dispose();
    _ctaUrlCtrl.dispose();
    _memberClientUserIdCtrl.dispose();
    _memberProfileIdCtrl.dispose();
    super.dispose();
  }

  /// The client user id the member presets (8, 9, 10) act on: QA's typed value,
  /// else the connected user's own — the id the SDK reports when it exposes
  /// client user ids, else the host-side login id. Empty only for a guest with
  /// no stored login, in which case the presets report that instead of opening a
  /// screen with an id that could never resolve.
  ///
  /// Same "effective value" idiom as [_effectiveGroupId]: prefilling a real id
  /// discovered at runtime is what lets the presets run out of the box, while
  /// still letting QA plug another member's id.
  String _effectiveMemberClientUserId(AppState app) {
    final typed = _memberClientUserIdCtrl.text.trim();
    if (typed.isNotEmpty) return typed;
    return (app.profile?.clientUserId ?? app.effectiveUserId).trim();
  }

  Future<void> _openRoute(
    BuildContext context, {
    required Widget Function(
      BuildContext routeContext,
      double bottomSafeAreaInset,
    )
    builder,
  }) {
    // Builder receives the pushed route's context so embedded callbacks
    // (onBack / onNavigateToLogin / onModifyUser) resolve their Navigator
    // from inside the route — same idiom as sheet_scenario, defensive
    // against the outer scenario State being torn down while the pushed
    // route is still on top. It also receives the device bottom gesture-area
    // inset to forward to the embedded SDK (see below).
    //
    // Wrap in `Scaffold` + `SafeArea(bottom: false)`. The `Scaffold` paints a
    // surface behind the status-bar inset (without it the unpainted top area
    // shows the route's black backdrop); `SafeArea(bottom: false)` offsets the
    // SDK's native top bar below the status bar. The bottom gesture-area inset
    // is NOT applied by the host SafeArea: the platform view consumes the
    // system insets (`consumeWindowInsets(systemBars)`), so instead the host
    // measures the device bottom inset off the raw View and forwards it to the
    // SDK via `bottomSafeAreaInset` — the same edge-to-edge idiom as the
    // Fullscreen / Modal / Sheet scenarios. The SDK then floats its own
    // bottom-pinned content (feed "Write a post" pill, comment composer + its
    // legal disclaimer) above the gesture area while the feed still scrolls
    // edge-to-edge underneath.
    final bottomSafeAreaInset = MediaQueryData.fromView(
      View.of(context),
    ).viewPadding.bottom;
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => Scaffold(
          body: SafeArea(
            bottom: false,
            child: builder(routeContext, bottomSafeAreaInset),
          ),
        ),
      ),
    );
  }

  /// Reconciles the locally-selected group id with the live `app.groups`
  /// snapshot — drops the selection if the picked group disappears from the
  /// stream (e.g. after a community switch).
  String? _validSelectedGroupId(List<OctopusGroup> groups) {
    final selected = _selectedGroupId;
    if (selected == null) return null;
    final stillThere = groups.any((g) => g.id == selected);
    return stillThere ? selected : null;
  }

  /// A sensible default group id picked from the live `app.groups` stream — the
  /// stable open [_defaultGroupName] group when present, else the first loaded
  /// group. `null` only when the stream is still empty (no community selected /
  /// groups not fetched yet).
  String? _defaultGroupId(List<OctopusGroup> groups) {
    if (groups.isEmpty) return null;
    for (final g in groups) {
      if (g.name == _defaultGroupName) return g.id;
    }
    return groups.first.id;
  }

  /// The group id presets 3 & 4 act on: QA's explicit pick once they have
  /// touched the dropdown, otherwise [_defaultGroupId]. Prefilling a *real*
  /// group id discovered at runtime is what lets these presets run out of the
  /// box without a manual selection, while still letting QA pick another group
  /// or an explicit "— (none)".
  String? _effectiveGroupId(List<OctopusGroup> groups) {
    if (_groupSelectionTouched) return _validSelectedGroupId(groups);
    return _defaultGroupId(groups);
  }

  /// The input-form panel rendered above the presets via [ScenarioScaffold]'s
  /// `liveState` slot.
  Widget _buildInputForm(BuildContext context, AppState app) {
    final theme = Theme.of(context);
    final groups = app.groups;
    final effectiveSelected = _effectiveGroupId(groups);
    final connectedFallback = (app.profile?.clientUserId ?? app.effectiveUserId)
        .trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Inputs', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            TextField(
              controller: _postIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Post id (presets 2 & 5)',
                helperText:
                    'Prefilled from OCTOPUS_DEMO_POST_ID when injected '
                    '(`--dart-define` injects a stable demo post by default). '
                    'Plug your own post id to open it in bridge mode; empty on '
                    'a keyless / public build.',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (!mounted) return;
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              // Key the field on its effective value so a default seeded once
              // the groups stream loads (or a later explicit pick) is reflected
              // in the displayed selection — DropdownButtonFormField only reads
              // initialValue on first build, so without this the dropdown would
              // show "—" while the presets acted on the seeded default.
              key: ValueKey<String>('group-dd-${effectiveSelected ?? 'none'}'),
              initialValue: effectiveSelected,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Group (presets 3 & 4 topicId)',
                helperText:
                    'Defaults to the "General" group (or the first available) '
                    'from the live OctopusSDK.groups stream so presets 3 & 4 '
                    'run out of the box; pick another group or "— (none)" to '
                    'override. Empty only while no community is selected or no '
                    'groups have been fetched yet.',
                border: OutlineInputBorder(),
              ),
              hint: const Text('—'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('— (none)'),
                ),
                for (final group in groups)
                  DropdownMenuItem<String?>(
                    value: group.id,
                    child: Text(
                      '${group.name} · ${group.id}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (!mounted) return;
                setState(() {
                  _groupSelectionTouched = true;
                  _selectedGroupId = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Prefilled post (preset 4)',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _prefillTextCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Prefill text',
                helperText:
                    'Min 10 / max 5000 chars. Shorten below 10 to observe '
                    'the typed TextTooShort validation error.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctaLabelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'CTA label (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _ctaUrlCtrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'CTA url (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Leave both CTA fields empty to attach no CTA. Filling only '
              'one surfaces a typed CtaLabelEmpty / CtaUrlEmpty error.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text('Member (presets 8-10)', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _memberClientUserIdCtrl,
              decoration: InputDecoration(
                labelText: 'Member clientUserId',
                helperText:
                    'Your app\'s own id for the member. Empty falls back to the '
                    'connected user\'s own id'
                    '${connectedFallback.isEmpty ? ' (none known — connect first)' : ' ("$connectedFallback")'}'
                    '. Resolved through the client-user-id lookup, so it needs '
                    'a community that exposes client user ids.',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (!mounted) return;
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _memberProfileIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Member Octopus profileId (preset 9)',
                helperText:
                    'Empty is fine: preset 9 resolves one with '
                    'fetchCommunityData(clientUserId:) and writes it back here.',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (!mounted) return;
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ScenarioScaffold(
      title: 'Initial screen',
      api: 'OctopusInitialScreen',
      description:
          'Mount the embedded community on a specific initial screen — main '
          'feed, a single post (bridge mode), a single group (bridge mode), '
          'the post editor, one member\'s posts or profile, the standalone '
          'OctopusPostDetailsScreen / OctopusProfileScreen widgets, or '
          'via the top-level showOctopusHomeScreen helper (auto bottom inset). '
          'Use the input form below to plug a real post id / group / prefill '
          'so QA exercises live content (not just not-found stubs). Each '
          'preset pushes a new route hosting the SDK directly; the SDK '
          "renders its own back arrow which pops the route.",
      resultTestId: 'initialScreen-result',
      liveState: _buildInputForm(context, app),
      presets: [
        ScenarioPreset(
          testId: 'qa-preset-initialScreen-1',
          label: 'Preset 1 · Open main feed',
          onRun: (setResult) async {
            try {
              demoLog.apiCall('OctopusHomeScreen', {
                'initialScreen': 'mainFeed (default)',
              });
              setResult(
                'Opening OctopusHomeScreen with the default initial screen '
                '(main feed). Tap the SDK back arrow to return.',
              );
              await _openRoute(
                context,
                builder: (routeContext, bottomSafeAreaInset) =>
                    OctopusHomeScreen(
                      theme: app.effectiveOctopusTheme(),
                      bottomSafeAreaInset: bottomSafeAreaInset,
                      showBackButton: true,
                      onBack: () => Navigator.of(routeContext).pop(),
                      onNavigateToLogin: () => Navigator.of(routeContext).push(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      ),
                      onModifyUser: (field) => Navigator.of(routeContext).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileEditPage(fieldToEdit: field),
                        ),
                      ),
                    ),
              );
              if (!mounted) return;
              setResult('Returned to scenario.');
            } catch (e) {
              setResult('Failed to open main feed: $e', isError: true);
            }
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-initialScreen-2',
          label: 'Preset 2 · Open post (bridge mode)',
          onRun: (setResult) async {
            final postId = _postIdCtrl.text.trim();
            if (postId.isEmpty) {
              setResult(
                'Post id is empty — fill the "Post id" field above to open a '
                'post in bridge mode.',
                isError: true,
              );
              return;
            }
            try {
              demoLog.apiCall('OctopusHomeScreen', {
                'initialScreen': 'post',
                'postId': postId,
              });
              setResult(
                'Opening OctopusHomeScreen with '
                'OctopusInitialScreen.post(PostScreenInfo(postId: '
                '"$postId")).',
              );
              await _openRoute(
                context,
                builder: (routeContext, bottomSafeAreaInset) =>
                    OctopusHomeScreen(
                      theme: app.effectiveOctopusTheme(),
                      bottomSafeAreaInset: bottomSafeAreaInset,
                      showBackButton: true,
                      onBack: () => Navigator.of(routeContext).pop(),
                      onNavigateToLogin: () => Navigator.of(routeContext).push(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      ),
                      onModifyUser: (field) => Navigator.of(routeContext).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileEditPage(fieldToEdit: field),
                        ),
                      ),
                      initialScreen: OctopusInitialScreen.post(
                        PostScreenInfo(postId: postId),
                      ),
                    ),
              );
              if (!mounted) return;
              setResult('Returned to scenario.');
            } catch (e) {
              setResult('Failed to open post bridge mode: $e', isError: true);
            }
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-initialScreen-3',
          label: 'Preset 3 · Open group (bridge mode)',
          onRun: (setResult) async {
            final groupId = _effectiveGroupId(app.groups);
            if (groupId == null || groupId.isEmpty) {
              setResult(
                'No group available — the OctopusSDK.groups stream is empty '
                '(no community selected or groups not fetched yet), so there '
                'is no default to fall back on. Open the Community tab first '
                'to load the groups, then retry.',
                isError: true,
              );
              return;
            }
            try {
              demoLog.apiCall('OctopusHomeScreen', {
                'initialScreen': 'group',
                'groupId': groupId,
              });
              setResult(
                'Opening OctopusHomeScreen with '
                'OctopusInitialScreen.group(GroupScreenInfo(groupId: '
                '"$groupId")).',
              );
              await _openRoute(
                context,
                builder: (routeContext, bottomSafeAreaInset) =>
                    OctopusHomeScreen(
                      theme: app.effectiveOctopusTheme(),
                      bottomSafeAreaInset: bottomSafeAreaInset,
                      showBackButton: true,
                      onBack: () => Navigator.of(routeContext).pop(),
                      onNavigateToLogin: () => Navigator.of(routeContext).push(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      ),
                      onModifyUser: (field) => Navigator.of(routeContext).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileEditPage(fieldToEdit: field),
                        ),
                      ),
                      initialScreen: OctopusInitialScreen.group(
                        GroupScreenInfo(groupId: groupId),
                      ),
                    ),
              );
              if (!mounted) return;
              setResult('Returned to scenario.');
            } catch (e) {
              setResult('Failed to open group bridge mode: $e', isError: true);
            }
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-initialScreen-4',
          label: 'Preset 4 · Open createPost (prefilled)',
          onRun: (setResult) async {
            final text = _prefillTextCtrl.text;
            final ctaLabel = _ctaLabelCtrl.text;
            final ctaUrl = _ctaUrlCtrl.text;
            final topicId = _effectiveGroupId(app.groups);

            // Build the optional CTA up-front so the OctopusPrefilledPost
            // factory can surface the typed CtaLabelEmpty / CtaUrlEmpty /
            // invalid-url errors itself (iso the iOS PrefilledPostFormState
            // builder flow). Both fields empty = no CTA attached.
            OctopusPostCTA? cta;
            if (ctaLabel.isNotEmpty || ctaUrl.isNotEmpty) {
              final parsedUrl = Uri.tryParse(ctaUrl);
              if (parsedUrl == null) {
                setResult(
                  'CTA url is not a valid URI: "$ctaUrl"',
                  isError: true,
                );
                return;
              }
              cta = OctopusPostCTA(url: parsedUrl, label: ctaLabel);
            }

            OctopusPrefilledPost prefill;
            try {
              prefill = OctopusPrefilledPost(
                text: text,
                topicId: topicId,
                cta: cta,
              );
            } on OctopusPrefilledPostValidationError catch (e) {
              setResult(
                'OctopusPrefilledPost rejected: ${e.runtimeType} '
                '(${e.message ?? 'no message'})',
                isError: true,
              );
              return;
            } catch (e) {
              setResult(
                'Failed to build OctopusPrefilledPost: $e',
                isError: true,
              );
              return;
            }

            StreamSubscription<OctopusEvent>? postCreatedSub;
            try {
              demoLog.apiCall('OctopusHomeScreen', {
                'initialScreen': 'createPost',
                'prefilledText': text,
                'topicId': topicId ?? '(none)',
                'cta': cta == null
                    ? '(none)'
                    : 'label="${cta.label}", url=${cta.url}',
              });
              setResult(
                'Opening OctopusHomeScreen with '
                'OctopusInitialScreen.createPost(...) using the inputs above. '
                'The host route auto-pops on PostCreated as a workaround — '
                'the native shell does not yet signal createPost dismissal '
                '(tracked internally). Image bytes are '
                'intentionally not provided (embedded createPost drops image '
                'bytes by design — use OctopusSDK.showOctopusCreatePostScreen '
                'for the image-share flow).',
              );

              // Measure the device bottom gesture-area inset off the raw View
              // and forward it to the SDK (edge-to-edge idiom, matching the
              // other scenarios) so the createPost editor's legal disclaimer
              // clears the gesture area while the editor stays edge-to-edge.
              final bottomSafeAreaInset = MediaQueryData.fromView(
                View.of(context),
              ).viewPadding.bottom;

              // Build the route up-front so the PostCreated listener can
              // remove *this specific route* by reference. `Navigator.pop()`
              // would target the navigator's current top, which may have
              // shifted if the user navigated within the SDK shell before
              // publishing (e.g. publish → native post-detail) — popping
              // blindly would tear down the wrong route.
              final route = MaterialPageRoute<void>(
                builder: (routeContext) => Scaffold(
                  body: SafeArea(
                    bottom: false,
                    child: OctopusHomeScreen(
                      theme: app.effectiveOctopusTheme(),
                      bottomSafeAreaInset: bottomSafeAreaInset,
                      showBackButton: true,
                      onBack: () => Navigator.of(routeContext).pop(),
                      onNavigateToLogin: () => Navigator.of(routeContext).push(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      ),
                      onModifyUser: (field) => Navigator.of(routeContext).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileEditPage(fieldToEdit: field),
                        ),
                      ),
                      initialScreen: OctopusInitialScreen.createPost(
                        CreatePostScreenInfo(prefilledPost: prefill),
                      ),
                    ),
                  ),
                ),
              );

              // Auto-pop the host route on the first PostCreated event so
              // QA gets the "publish → back to scenario" UX the standalone
              // OctopusSDK.showOctopusCreatePostScreen already provides on
              // both platforms. The native embedded shell currently keeps
              // navigating internally after publish (post-detail / feed) —
              // tracked internally via the cross-platform-sync issues.
              // The `OctopusSDK.events` stream is a non-replaying broadcast
              // controller, so the microtask gap between `.listen()` and the
              // following `Navigator.push` cannot deliver a buffered stale
              // event. `.take(1)` enforces single-shot dispatch; the cancel
              // in `finally` covers the back-tap-before-publish case so a
              // delayed PostCreated can't pop a route the user already
              // dismissed.
              postCreatedSub = OctopusSDK.events
                  .where((e) => e is PostCreatedEvent)
                  .take(1)
                  .listen((_) {
                    if (route.isActive) {
                      route.navigator?.removeRoute(route);
                    }
                  });

              await Navigator.of(context).push<void>(route);
              if (!mounted) return;
              setResult('Returned to scenario.');
            } catch (e) {
              setResult('Failed to open createPost: $e', isError: true);
            } finally {
              await postCreatedSub?.cancel();
            }
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-initialScreen-5',
          label: 'Preset 5 · Open standalone OctopusPostDetailsScreen',
          onRun: (setResult) async {
            final postId = _postIdCtrl.text.trim();
            if (postId.isEmpty) {
              setResult(
                'Post id is empty — fill the "Post id" field above to open '
                'OctopusPostDetailsScreen.',
                isError: true,
              );
              return;
            }
            try {
              demoLog.apiCall('OctopusPostDetailsScreen', {'postId': postId});
              setResult(
                'Opening the standalone OctopusPostDetailsScreen widget with '
                'postId "$postId" (ergonomic shorthand for OctopusHomeScreen '
                '+ OctopusInitialScreen.post(...)). Tap the SDK back chevron '
                '— the host wires `onBack` to pop the route. iOS '
                'swipe-from-left / Android system back work too, '
                'independently (they pop the MaterialPageRoute directly).',
              );
              await _openRoute(
                context,
                builder: (routeContext, bottomSafeAreaInset) =>
                    OctopusPostDetailsScreen(
                      postId: postId,
                      theme: app.effectiveOctopusTheme(),
                      bottomSafeAreaInset: bottomSafeAreaInset,
                      // `onBack` wires the SDK back chevron (rendered on iOS by
                      // the bridge's `showBackButton` backfill, on Android by
                      // the native top app bar) to a host-owned route pop.
                      // Without this the chevron would be inert at the
                      // bridge-mode start destination.
                      onBack: () => Navigator.of(routeContext).pop(),
                      onNavigateToLogin: () => Navigator.of(routeContext).push(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      ),
                      onModifyUser: (field) => Navigator.of(routeContext).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileEditPage(fieldToEdit: field),
                        ),
                      ),
                    ),
              );
              if (!mounted) return;
              setResult('Returned to scenario.');
            } catch (e) {
              setResult(
                'Failed to open standalone post details: $e',
                isError: true,
              );
            }
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-initialScreen-6',
          label: 'Preset 6 · Standalone editor + signed image share',
          onRun: (setResult) async {
            final text = _prefillTextCtrl.text;
            final ctaLabel = _ctaLabelCtrl.text;
            final ctaUrl = _ctaUrlCtrl.text;
            final topicId = _effectiveGroupId(app.groups);

            OctopusPostCTA? cta;
            if (ctaLabel.isNotEmpty || ctaUrl.isNotEmpty) {
              final parsedUrl = Uri.tryParse(ctaUrl);
              if (parsedUrl == null) {
                setResult(
                  'CTA url is not a valid URI: "$ctaUrl"',
                  isError: true,
                );
                return;
              }
              cta = OctopusPostCTA(url: parsedUrl, label: ctaLabel);
            }

            // Carry a real image so this exercises the bridge-share image path:
            // showOctopusCreatePostScreen forwards image bytes to the native
            // editor (unlike the embedded createPost route, which drops them).
            Uint8List imageBytes;
            try {
              final data = await rootBundle.load('assets/logo.png');
              imageBytes = data.buffer.asUint8List();
            } catch (e) {
              setResult('Failed to load assets/logo.png: $e', isError: true);
              return;
            }

            OctopusPrefilledPost prefill;
            try {
              prefill = OctopusPrefilledPost(
                text: text,
                image: imageBytes,
                topicId: topicId,
                cta: cta,
              );
            } on OctopusPrefilledPostValidationError catch (e) {
              setResult(
                'OctopusPrefilledPost rejected: ${e.runtimeType} '
                '(${e.message ?? 'no message'})',
                isError: true,
              );
              return;
            }

            try {
              demoLog.apiCall('showOctopusCreatePostScreen', {
                'prefilledText': text,
                'image': 'assets/logo.png (${imageBytes.length} bytes)',
                'topicId': topicId ?? '(none)',
                'cta': cta == null
                    ? '(none)'
                    : 'label="${cta.label}", url=${cta.url}',
                'bridgeShareTokenProvider': hasInjectedSsoSecret
                    ? 'set (signs via demo SSO secret)'
                    : 'set (returns null — no SSO secret injected)',
              });
              setResult(
                'Opening the standalone native editor via '
                'OctopusSDK.showOctopusCreatePostScreen(...) with a prefilled '
                'image share and a bridgeShareTokenProvider. In a community '
                'that forbids member pictures the SDK invokes the provider at '
                'publish time with the content fingerprint; the demo signer '
                'returns an HS256 JWT (or null when no SSO secret is injected). '
                'Wired on both platforms. When the signer returns null, iOS '
                'shows a signing error and keeps the editor open, while Android '
                'lets the server reject the unsigned image. Mirrors the native '
                'sample bridge-share section.',
              );
              await OctopusSDK().showOctopusCreatePostScreen(
                info: CreatePostScreenInfo(
                  prefilledPost: prefill,
                  // signBridgeFingerprint is synchronous (String?); wrap it to
                  // match the Future<String?> provider contract, mirroring the
                  // bridge scenario's _hostBridgeTokenProvider.
                  bridgeShareTokenProvider: (fingerprint) async =>
                      BridgeTokenSigner.signBridgeFingerprint(fingerprint),
                ),
                theme: app.effectiveOctopusTheme(),
              );
            } catch (e) {
              setResult(
                'Failed to open the standalone create-post editor: $e',
                isError: true,
              );
            }
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-initialScreen-7',
          label:
              'Preset 7 · Open via showOctopusHomeScreen helper (auto inset)',
          onRun: (setResult) async {
            try {
              demoLog.apiCall('showOctopusHomeScreen', {
                'bottomSafeAreaInset': 'null (auto)',
              });
              setResult(
                'Opening the community via the top-level '
                'OctopusSDK().showOctopusHomeScreen(context) helper — the '
                'client-facing entry point (unlike the other presets, which '
                'mount the OctopusHomeScreen widget directly and forward the '
                'inset themselves). No bottomSafeAreaInset is passed, so the '
                'helper auto-reserves the launching view bottom safe area: on '
                'edge-to-edge Android (API 35+) the floating "Write a post" '
                'button clears the system navigation bar. Tap the SDK back '
                'arrow to return.',
              );
              // Deliberately NO bottomSafeAreaInset argument: this exercises the
              // helper's auto-default (the exact path a host app uses), which is
              // what keeps the floating button above the Android system nav bar.
              // On Android, passing `bottomSafeAreaInset: 0` here reproduces the
              // pre-fix overlap. On iOS it does not: 0 falls back to the bridge
              // default, which sits on top of the system safe area, so the button
              // stays clear either way. iOS is NOT unaffected by the auto-default
              // though — it used to double-count it (the device inset applied on
              // top of the safe area again); the iOS bridge now normalizes it.
              //
              // Callbacks resolve their Navigator from the scenario's own
              // `context` (not a route context): unlike the sibling presets,
              // the helper owns its MaterialPageRoute internally and never
              // exposes one — so passing our own context IS the client-facing
              // pattern. Safe: the scenario route stays mounted beneath the
              // SDK route the helper pushes onto the same navigator.
              await OctopusSDK().showOctopusHomeScreen(
                context,
                theme: app.effectiveOctopusTheme(),
                onNavigateToLogin: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const LoginPage())),
                onModifyUser: (field) => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProfileEditPage(fieldToEdit: field),
                  ),
                ),
              );
              if (!mounted) return;
              setResult('Returned to scenario.');
            } catch (e) {
              setResult(
                'Failed to open via showOctopusHomeScreen helper: $e',
                isError: true,
              );
            }
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-initialScreen-8',
          label: 'Preset 8 · Open member activity (by clientUserId)',
          onRun: (setResult) async {
            final clientUserId = _effectiveMemberClientUserId(app);
            if (clientUserId.isEmpty) {
              setResult(
                'No member clientUserId — fill the "Member clientUserId" field '
                'above, or connect a user so the presets can fall back to their '
                'own id.',
                isError: true,
              );
              return;
            }
            try {
              demoLog.apiCall('OctopusHomeScreen', {
                'initialScreen': 'activity',
                'clientUserId': clientUserId,
              });
              setResult(
                'Opening OctopusHomeScreen with '
                'OctopusInitialScreen.activity('
                'ActivityScreenInfo.clientUserId("$clientUserId")) — the '
                'posts-only screen titled "{author}\'s Posts", no profile '
                'header and no tabs. Pointing it at the connected user\'s own '
                'id instead opens the two-tab activity screen on both '
                'platforms. An id that does not resolve (unknown mapping, or a '
                'community that does not expose client user ids) shows the '
                'empty state — it never falls back to another member.',
              );
              await _openRoute(
                context,
                builder: (routeContext, bottomSafeAreaInset) =>
                    OctopusHomeScreen(
                      theme: app.effectiveOctopusTheme(),
                      bottomSafeAreaInset: bottomSafeAreaInset,
                      showBackButton: true,
                      onBack: () => Navigator.of(routeContext).pop(),
                      onNavigateToLogin: () => Navigator.of(routeContext).push(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      ),
                      onModifyUser: (field) => Navigator.of(routeContext).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileEditPage(fieldToEdit: field),
                        ),
                      ),
                      initialScreen: OctopusInitialScreen.activity(
                        ActivityScreenInfo.clientUserId(clientUserId),
                      ),
                    ),
              );
              if (!mounted) return;
              setResult('Returned to scenario.');
            } catch (e) {
              setResult(
                'Failed to open member activity by clientUserId: $e',
                isError: true,
              );
            }
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-initialScreen-9',
          label: 'Preset 9 · Open member activity (by profileId)',
          onRun: (setResult) async {
            // Resolve an Octopus profile id when QA has not pasted one: this is
            // the round-trip a host does when all it holds is its own id
            // (fetchCommunityData → profileId), and it keeps the preset
            // one-tap. The resolved id is written back into the field so the
            // next run skips the lookup and QA can see what was used.
            var profileId = _memberProfileIdCtrl.text.trim();
            if (profileId.isEmpty) {
              final clientUserId = _effectiveMemberClientUserId(app);
              if (clientUserId.isEmpty) {
                setResult(
                  'No profileId typed and no clientUserId to resolve one from '
                  '— fill either field above, or connect a user.',
                  isError: true,
                );
                return;
              }
              try {
                demoLog.apiCall('fetchCommunityData', {
                  'clientUserId': clientUserId,
                });
                final data = await app.octopus.fetchCommunityData(
                  clientUserId: clientUserId,
                );
                if (!mounted) return;
                if (data == null) {
                  setResult(
                    'No Octopus profile for clientUserId "$clientUserId", so '
                    'there is no profileId to open. Either the member has never '
                    'used the community, or the community does not expose '
                    'client user ids — paste an Octopus profileId instead.',
                    isError: true,
                  );
                  return;
                }
                profileId = data.profileId;
                _memberProfileIdCtrl.text = profileId;
              } catch (e) {
                setResult(
                  'Failed to resolve a profileId from clientUserId '
                  '"$clientUserId": $e',
                  isError: true,
                );
                return;
              }
            }
            // The resolve branch above awaits, so check the captured context
            // itself (not `mounted`) before pushing the route — this closure
            // holds the build context, which is what `_openRoute` uses.
            if (!context.mounted) return;
            try {
              demoLog.apiCall('OctopusHomeScreen', {
                'initialScreen': 'activity',
                'profileId': profileId,
              });
              setResult(
                'Opening OctopusHomeScreen with '
                'OctopusInitialScreen.activity('
                'ActivityScreenInfo.profileId("$profileId")) — same screen as '
                'preset 8, reached with the Octopus id instead: no '
                'client-user-id lookup and no exposeClientUserId requirement.',
              );
              await _openRoute(
                context,
                builder: (routeContext, bottomSafeAreaInset) =>
                    OctopusHomeScreen(
                      theme: app.effectiveOctopusTheme(),
                      bottomSafeAreaInset: bottomSafeAreaInset,
                      showBackButton: true,
                      onBack: () => Navigator.of(routeContext).pop(),
                      onNavigateToLogin: () => Navigator.of(routeContext).push(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      ),
                      onModifyUser: (field) => Navigator.of(routeContext).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileEditPage(fieldToEdit: field),
                        ),
                      ),
                      initialScreen: OctopusInitialScreen.activity(
                        ActivityScreenInfo.profileId(profileId),
                      ),
                    ),
              );
              if (!mounted) return;
              setResult('Returned to scenario.');
            } catch (e) {
              setResult(
                'Failed to open member activity by profileId: $e',
                isError: true,
              );
            }
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-initialScreen-10',
          label: 'Preset 10 · Open member profile (OctopusProfileScreen)',
          onRun: (setResult) async {
            final clientUserId = _effectiveMemberClientUserId(app);
            if (clientUserId.isEmpty) {
              setResult(
                'No member clientUserId — fill the "Member clientUserId" field '
                'above, or connect a user.',
                isError: true,
              );
              return;
            }
            try {
              demoLog.apiCall('OctopusProfileScreen', {
                'clientUserId': clientUserId,
              });
              setResult(
                'Opening the standalone OctopusProfileScreen widget with '
                'clientUserId "$clientUserId" — the read-only profile of that '
                'member. This is what a Unified Profile host pushes from its '
                'own profile page once onNavigateToProfile made the SDK stop '
                'showing profiles itself (the Community tab does exactly that: '
                'turn the Settings toggle on, tap a member, then use the '
                'buttons at the bottom of the host page).',
              );
              await _openRoute(
                context,
                builder: (routeContext, bottomSafeAreaInset) =>
                    OctopusProfileScreen(
                      clientUserId: clientUserId,
                      theme: app.effectiveOctopusTheme(),
                      bottomSafeAreaInset: bottomSafeAreaInset,
                      onBack: () => Navigator.of(routeContext).pop(),
                      onNavigateToLogin: () => Navigator.of(routeContext).push(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      ),
                    ),
              );
              if (!mounted) return;
              setResult('Returned to scenario.');
            } catch (e) {
              setResult('Failed to open member profile: $e', isError: true);
            }
          },
        ),
        ScenarioPreset(
          testId: 'qa-preset-initialScreen-11',
          label: 'Preset 11 · Open my own profile (no id)',
          onRun: (setResult) async {
            try {
              demoLog.apiCall('OctopusProfileScreen', {'clientUserId': 'null'});
              setResult(
                'Opening OctopusProfileScreen() with no clientUserId — the '
                'connected user\'s OWN profile, with its edit affordances '
                '(onModifyUser fires the host edit page). With no connected '
                'user the SDK shows its unavailable state and onNavigateToLogin '
                'is the way out.',
              );
              await _openRoute(
                context,
                builder: (routeContext, bottomSafeAreaInset) =>
                    OctopusProfileScreen(
                      theme: app.effectiveOctopusTheme(),
                      bottomSafeAreaInset: bottomSafeAreaInset,
                      onBack: () => Navigator.of(routeContext).pop(),
                      onNavigateToLogin: () => Navigator.of(routeContext).push(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      ),
                      onModifyUser: (field) => Navigator.of(routeContext).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileEditPage(fieldToEdit: field),
                        ),
                      ),
                    ),
              );
              if (!mounted) return;
              setResult('Returned to scenario.');
            } catch (e) {
              setResult('Failed to open my own profile: $e', isError: true);
            }
          },
        ),
      ],
    );
  }
}
